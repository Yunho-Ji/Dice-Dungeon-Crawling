# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리 및 장비를 표시하는 UI입니다.
extends CanvasLayer

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed
# [신규] Apeloot 호환성 시그널 모음
signal item_placed(item)
signal item_updated(item)
signal item_removed(item)
signal item_moved(item, from_slot, to_slot) 
signal item_reparented(item, new_parent)

# --- 노드 참조 ---
@onready var main_panel = $CenterContainer/MainPanel
@onready var inventory_interface = $CenterContainer/MainPanel/VBox/MainHBox/InventorySection/InventoryInterface
@onready var gold_label = $CenterContainer/MainPanel/VBox/Footer/GoldLabel
@onready var close_button = $CenterContainer/MainPanel/VBox/Header/CloseButton

# 장비 슬롯 참조
@onready var head_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/HeadSlot
@onready var top_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/TopSlot
@onready var bottom_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/BottomSlot
@onready var shoes_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/ShoesSlot
@onready var left_hand_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/LeftHandSlot
@onready var right_hand_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/RightHandSlot
@onready var acc_slots = [
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc1,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc2,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc3,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc4
]
@onready var equipment_items_node = %EquipmentItems
@onready var trash_bin = %TrashBin

# --- 장비 시스템 관련 변수 ---
var slot_to_key = {}
var all_slots = []
var items = [] # Apeloot 호환성을 위한 장착 아이템 목록

# Apeloot 인터페이스 호환을 위한 변수들
var pickup_only = false
var type_only = true
var single_slot = false
var slot_count = 10
var slot_background = null # [신규] ItemSlot 참조용
var slot_icon = null       # [신규] ItemSlot 참조용

# [신규] Apeloot 인벤토리 식별자
var id = "equipment_screen"

func _enter_tree():
	# Apeloot 시스템에 이 화면을 인벤토리로 등록합니다.
	Apeloot.inventory_refs[id] = self

func _exit_tree():
	# [신규] 인벤토리 데이터 백업 (화면 파괴 시)
	if inventory_interface:
		PlayerManager.inventory_data = inventory_interface.item_states.duplicate(true)
		print("DEBUG: Inventory saved to PlayerManager (Count: ", PlayerManager.inventory_data.size(), ")")

	# 화면이 제거될 때 참조를 삭제합니다.
	if Apeloot.inventory_refs.get(id) == self:
		Apeloot.inventory_refs.erase(id)

func get_global_rect() -> Rect2:
	# 장비 슬롯 영역을 반환하여 마우스 위치 감지에 사용
	var section = get_node_or_null("CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection")
	if section:
		var rect = section.get_global_rect()
		if rect.size.x > 0:
			return rect
	return main_panel.get_global_rect() if main_panel else Rect2()

func calculate_item_position(_item, slot_id: int) -> Vector2:
	if slot_id >= 0 and slot_id < all_slots.size():
		var slot = all_slots[slot_id]
		# 슬롯의 전역 위치를 반환 (Apeloot 프리뷰가 이 위치로 스냅됨)
		return slot.global_position
	return get_viewport().get_mouse_position()

func _ready():
	print("DEBUG: InventoryScreen _ready called.")
	
	# 시그널 연결
	close_button.pressed.connect(_on_close_button_pressed)
	SignalBus.connect("gold_changed", _on_gold_changed)
	self.visibility_changed.connect(_on_visibility_changed)
	
	_setup_equipment_slots()
	
	# [신규] 인벤토리 데이터 복원 (PlayerManager로부터)
	if not PlayerManager.inventory_data.is_empty():
		print("DEBUG: Inventory restored from PlayerManager (Count: ", PlayerManager.inventory_data.size(), ")")
		# UI 구성이 완료된 후 데이터 로드 (안전장치)
		call_deferred("_restore_inventory")
		
	hide_screen()

func _restore_inventory():
	if inventory_interface and not PlayerManager.inventory_data.is_empty():
		inventory_interface.initialize_inventory(PlayerManager.inventory_data)

func _on_visibility_changed():
	if self.visible:
		update_gold_display()
		_refresh_equipment_visuals()
		
		# [신규] 전투 중이면 장비 슬롯 드래그 잠금
		var is_combat = EconomyManager.get_node("/root/GameManager").current_game_phase == GameManager.GamePhase.COMBAT
		for slot in all_slots:
			if slot:
				slot.can_drag = not is_combat # 전투 중이 아닐 때만 드래그 가능

# 장비 슬롯 구분 및 초기 설정
func _setup_equipment_slots():
	all_slots = [
		head_slot, top_slot, bottom_slot, shoes_slot,
		left_hand_slot, right_hand_slot
	] + acc_slots
	
	var keys = [
		"head", "top", "bottom", "shoes",
		"left_hand", "right_hand",
		"accessory_1", "accessory_2", "accessory_3", "accessory_4"
	]
	
	for i in range(all_slots.size()):
		var slot = all_slots[i]
		var key = keys[i]
		slot_to_key[i] = key
		slot.parent_inventory = self
		slot.slot_id = i
		
		# [신규] 슬롯에 라벨 추가
		var label = Label.new()
		label.text = _get_slot_name_korean(key)
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5)) # 반투명
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE # [중요] 드롭 이벤트 방해 금지
		slot.add_child(label)
	
	head_slot.tooltip_text = "머리"
	top_slot.tooltip_text = "상의"
	bottom_slot.tooltip_text = "하의"
	shoes_slot.tooltip_text = "신발"
	left_hand_slot.tooltip_text = "왼손 (무기/방패)"
	right_hand_slot.tooltip_text = "오른손 (무기/방패)"
	for i in range(acc_slots.size()):
		acc_slots[i].tooltip_text = "장신구 %d" % (i + 1)

func _get_slot_name_korean(key: String) -> String:
	match key:
		"head": return "머리"
		"top": return "상의"
		"bottom": return "하의"
		"shoes": return "신발"
		"left_hand": return "왼손"
		"right_hand": return "오른손"
		"accessory_1", "accessory_2", "accessory_3", "accessory_4": return "장신구"
	return ""

# --- Apeloot GridInventory 인터페이스 구현 ---

func get_slot_by_index(index: int):
	if index >= 0 and index < all_slots.size():
		return all_slots[index]
	return null

func get_item_at_slot(index: int):
	var slot = get_slot_by_index(index)
	if slot:
		return slot.occupying_item
	return null

func find_slot_at_position(pos: Vector2) -> int:

	# ItemSlot에서 넘겨주는 pos는 해당 슬롯 기준 로컬 좌표일 수 있음

	# 따라서 전역 마우스 좌표를 사용하는 것이 더 안전함

	var global_pos = get_viewport().get_mouse_position()

	

	for i in range(all_slots.size()):

		var rect = all_slots[i].get_global_rect()

		if rect.has_point(global_pos):

			# print("DEBUG: InventoryScreen find_slot_at_position: Found slot ", i)

			return i

	return -1



func can_place_item(item, slot_id: int) -> bool:
	print("DEBUG: InventoryScreen can_place_item called for item ", item.id, " at slot ", slot_id)
	if slot_id == -1: return false
	
	# [신규] 전투 중 장비 교체 제한
	if EconomyManager.get_node("/root/GameManager").current_game_phase == GameManager.GamePhase.COMBAT:
		print("DEBUG: 전투 중에는 장비를 교체할 수 없습니다.")
		return false
	
	var slot_key = slot_to_key.get(slot_id, "")
	var item_data = Apeloot.items.get(item.id, {})
	var equip_type = item_data.get("equip_type", "none")
	
	# 1. 장착 타입(부위) 체크
	var type_match = false
	match slot_key:
		"head": type_match = (equip_type == "head")
		"top": type_match = (equip_type == "top")
		"bottom": type_match = (equip_type == "bottom")
		"shoes": type_match = (equip_type == "shoes")
		"left_hand", "right_hand": type_match = (equip_type in ["weapon", "shield"])
		"accessory_1", "accessory_2", "accessory_3", "accessory_4": type_match = (equip_type == "accessory")
	
	if not type_match:
		print("DEBUG: 장착 실패 (타입 불일치) - Slot:", slot_key, " ItemType:", equip_type, " ItemID:", item.id)
		return false
	
	# 2. [신규] 스탯 요구사항 체크
	if not PlayerManager.can_equip_item(item_data):
		print("DEBUG: InventoryScreen: 요구 능력치 부족으로 장착 불가.")
		return false
		
	return true

func handle_item_drop(dragged_item, target_slot_id: int):
	print("DEBUG: InventoryScreen: handle_item_drop called. Item:", dragged_item.id, ", Slot:", target_slot_id)
	
	if can_place_item(dragged_item, target_slot_id):
		var slot_key = slot_to_key[target_slot_id]
		
		# [수정] 아이템의 인스턴스 데이터를 포함하여 저장
		var item_data = {
			"id": dragged_item.id,
			"rarity": dragged_item.rarity,
			"stats": dragged_item.stats.duplicate(),
			"price": dragged_item.price,
			"instance_id": dragged_item.instance_id
		}
		
		var target_slot = all_slots[target_slot_id]
		var old_item_node = target_slot.occupying_item
		
		# 1. 기존 장비가 있다면 가방으로 이동 시도
		if old_item_node:
			print("DEBUG: InventoryScreen: 기존 장비 가방으로 이동 시도 - ", old_item_node.id)
			if inventory_interface.try_fit_and_place(old_item_node):
				# 가방으로 이동 성공 시 PlayerManager에서도 해제됨 (deregister_item 호출되므로)
				pass
			else:
				print("WARNING: 가방 공간 부족으로 교환 실패")
				# 가방이 꽉 찼으면 바닥에 버리거나(추후 구현) 일단 실패 처리
				# 여기서는 안전을 위해 실패로 처리하고 드래그된 아이템을 원래대로 돌림
				return false
		
		# 2. 새 아이템 장착 (PlayerManager)
		PlayerManager.equip_item(slot_key, item_data)
		
		# 3. 드래그된 아이템을 장비창의 자식으로 reparent
		if dragged_item.parent_inventory != self:
			dragged_item.reparent(equipment_items_node)
			dragged_item.parent_inventory = self
		
		# [신규] 장착 상태 태그 설정
		dragged_item.location_tag = "equipment"
			
		# 4. 슬롯에 스냅 및 등록
		snap_item_to_grid(dragged_item, target_slot_id)
		
		# [수정] 드래그 종료 처리
		if dragged_item.has_node("ItemTexture"):
			dragged_item.get_node("ItemTexture").end_drag()
			
		return true
	else:
		# 장착 실패 시각적 피드백
		print("DEBUG: InventoryScreen: 장착 실패 (조건 미달)")
		if target_slot_id != -1:
			flash_slot_warning(target_slot_id)
		return false

func flash_slot_warning(slot_id: int):
	var slot = all_slots[slot_id]
	var original_color = Color(1, 1, 1, 1)
	var warning_color = Color(1, 0.3, 0.3, 1) # 붉은색
	
	var tween = create_tween()
	tween.tween_property(slot, "modulate", warning_color, 0.1)
	tween.tween_property(slot, "modulate", original_color, 0.1)
	tween.tween_property(slot, "modulate", warning_color, 0.1)
	tween.tween_property(slot, "modulate", original_color, 0.1)

func snap_item_to_grid(item, slot_id: int):
	var slot = all_slots[slot_id]
	# 아이템 위치를 슬롯 중앙으로 맞춤
	item.global_position = slot.global_position + (slot.size / 2.0) - (item.get_node("ItemTexture").size / 2.0)
	item.previous_center_slot = slot_id
	if not items.has(item):
		items.append(item)
	
	slot.occupying_item = item
	slot.full = true

func get_rotated_pattern(item):
	# 장비창에서는 항상 1x1로 간주하여 체크를 간소화하거나 
	# Apeloot의 기본 로직을 사용 (여기서는 1x1 리턴)
	return [[1]]

func remove_item(item):
	var slot_id = item.previous_center_slot
	if slot_id != -1:
		var slot = all_slots[slot_id]
		slot.occupying_item = null
		slot.full = false
		PlayerManager.unequip_item(slot_to_key[slot_id])
	
	items.erase(item)
	if is_instance_valid(item):
		item.queue_free()

func deregister_item(item):
	# 드래그 시작 시 호출됨
	var slot_id = item.previous_center_slot
	if slot_id != -1:
		var slot = all_slots[slot_id]
		slot.occupying_item = null
		slot.full = false
		PlayerManager.unequip_item(slot_to_key[slot_id])
	items.erase(item)

# --- 기본 UI 로직 ---

func show_screen():
	print("InventoryScreen: 화면 표시")
	self.visible = true

func hide_screen():
	self.visible = false

func update_gold_display(gold_amount: int = -1):
	if gold_amount == -1:
		gold_amount = EconomyManager.get_gold()
	gold_label.text = "소지 골드: %d G" % gold_amount

func _process(_delta):
	_update_drag_feedback()

func _update_drag_feedback():
	# 드래그 중인 아이템이 없으면 리턴
	# Apeloot의 내부 구조에 따라 드래그 중인 아이템을 찾는 방식이 다를 수 있음
	# 여기서는 일반적인 DragPreview 방식을 가정하거나 Apeloot 문서를 참고해야 함
	# Apeloot는 보통 get_viewport().gui_get_drag_data()를 사용하므로 직접 접근이 어려울 수 있음
	# 따라서 여기서는 '마우스 아래의 슬롯'을 찾고 그 슬롯의 상태만 업데이트
	
	var mouse_pos = get_viewport().get_mouse_position()
	var hovered_slot_index = find_slot_at_position(mouse_pos)
	
	# 모든 슬롯 초기화
	for slot in all_slots:
		slot.modulate = Color(1, 1, 1, 1)
	
	if hovered_slot_index != -1:
		var slot = all_slots[hovered_slot_index]
		
		# 드래그 데이터가 있는지 확인 (Godot 내장 드래그 시스템)
		# 하지만 Godot의 _process에서는 get_viewport().gui_is_dragging() 같은 함수가 명확하지 않음.
		# 대안: 마우스가 눌려있고 슬롯 위에 있을 때 틴트 처리 (약식)
		
		# [주의] Apeloot의 드래그 시스템과 연동하려면 Apeloot 코드를 수정하거나 
		# Apeloot가 제공하는 시그널을 써야 함. 현재는 간단히 hover 효과만 줌.
		pass

# [신규] 장비 슬롯 시각화 업데이트
func _refresh_equipment_visuals():
	# 기존에 생성된 아이템 노드 제거
	for item in items.duplicate():
		if is_instance_valid(item):
			item.queue_free()
	items.clear()
	
	# 모든 슬롯 비우기
	for slot in all_slots:
		slot.occupying_item = null
		slot.full = false
	
	# PlayerManager의 데이터를 바탕으로 아이템 재생성
	for i in range(all_slots.size()):
		var key = slot_to_key[i]
		var item_info = PlayerManager.equipment.get(key)
		if item_info and item_info.has("id"):
			var item_node = _spawn_item_node_with_data(item_info)
			snap_item_to_grid(item_node, i)

# 아이템 노드 생성을 위한 헬퍼 (데이터 포함)
func _spawn_item_node_with_data(item_data: Dictionary):
	var item_scene = preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item = item_scene.instantiate()
	
	# 기본 정보 설정
	item.id = item_data["id"]
	
	# 인스턴스 데이터 복원
	if item_data.has("instance_id"): item.instance_id = item_data["instance_id"]
	if item_data.has("rarity"): item.rarity = item_data["rarity"]
	if item_data.has("stats"): item.stats = item_data["stats"].duplicate()
	if item_data.has("price"): item.price = item_data["price"]
	
	item.parent_inventory = self
	equipment_items_node.add_child(item)
	return item

# Apeloot 호환성 함수: 아이템 복구용 (드롭 실패 시 호출됨)
func try_fit_and_place(item) -> bool:
	print("DEBUG: InventoryScreen: try_fit_and_place called for item ", item.id)
	# 장비창에서는 '빈 공간 찾기'가 아니라 '원래 있던 슬롯'으로 돌아가는 것이 기본 복구 동작
	if item.previous_center_slot != -1:
		snap_item_to_grid(item, item.previous_center_slot)
		
		# 복구 성공 시 다시 장착 상태로 간주 (Unequip을 취소하는 셈)
		var key = slot_to_key.get(item.previous_center_slot)
		if key:
			# [수정] 아이템의 인스턴스 데이터를 보존하여 재장착
			var item_data = {
				"id": item.id,
				"rarity": item.rarity,
				"stats": item.stats.duplicate(),
				"price": item.price,
				"instance_id": item.instance_id
			}
			PlayerManager.equip_item(key, item_data)
		return true
	return false

# --- 시그널 핸들러 ---
func _on_gold_changed(new_gold: int, _delta: int):
	update_gold_display(new_gold)

func _on_close_button_pressed():
	hide_screen()
	emit_signal("inventory_closed")

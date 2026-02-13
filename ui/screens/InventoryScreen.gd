# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리 및 장비를 표시하는 UI입니다.
extends CanvasLayer

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed

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
var single_slot = true
var slot_count = 10
var slot_background = null # [신규] ItemSlot 참조용
var slot_icon = null       # [신규] ItemSlot 참조용

func _ready():
	print("DEBUG: InventoryScreen _ready called.")
	
	# 시그널 연결
	close_button.pressed.connect(_on_close_button_pressed)
	SignalBus.connect("gold_changed", _on_gold_changed)
	self.visibility_changed.connect(_on_visibility_changed)
	
	_setup_equipment_slots()
	hide_screen()

func _on_visibility_changed():
	if self.visible:
		update_gold_display()
		_refresh_equipment_visuals()

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
	
	head_slot.tooltip_text = "머리"
	top_slot.tooltip_text = "상의"
	bottom_slot.tooltip_text = "하의"
	shoes_slot.tooltip_text = "신발"
	left_hand_slot.tooltip_text = "왼손 (무기/방패)"
	right_hand_slot.tooltip_text = "오른손 (무기/방패)"
	for i in range(acc_slots.size()):
		acc_slots[i].tooltip_text = "장신구 %d" % (i + 1)

# --- Apeloot GridInventory 인터페이스 구현 ---

func find_slot_at_position(pos: Vector2) -> int:
	# ItemSlot에서 넘겨주는 pos는 로컬이므로 전역으로 변환하여 체크
	var global_pos = get_viewport().get_mouse_position()
	for i in range(all_slots.size()):
		if all_slots[i].get_global_rect().has_point(global_pos):
			return i
	return -1

func can_place_item(item, slot_id: int) -> bool:
	if slot_id == -1: return false
	
	var slot_key = slot_to_key.get(slot_id, "")
	var item_data = Apeloot.items.get(item.id, {})
	var equip_type = item_data.get("equip_type", "none")
	
	match slot_key:
		"head": return equip_type == "head"
		"top": return equip_type == "top"
		"bottom": return equip_type == "bottom"
		"shoes": return equip_type == "shoes"
		"left_hand", "right_hand": return equip_type in ["weapon", "shield"]
		"accessory_1", "accessory_2", "accessory_3", "accessory_4": return equip_type == "accessory"
	
	return false

func handle_item_drop(dragged_item, target_slot_id: int):
	if can_place_item(dragged_item, target_slot_id):
		var slot_key = slot_to_key[target_slot_id]
		var item_data = Apeloot.items[dragged_item.id].duplicate()
		item_data["id"] = dragged_item.id # 복구용 ID 저장
		
		# PlayerManager에 장착 데이터 반영
		PlayerManager.equip_item(slot_key, item_data)
		
		# 기존 장착 아이템 처리 (교체 로직)
		var target_slot = all_slots[target_slot_id]
		if target_slot.occupying_item:
			var old_item = target_slot.occupying_item
			# 기존 아이템을 가방으로 돌려보내기 시도
			if not inventory_interface.try_fit_and_place(old_item):
				# 가방에 자리가 없으면 바닥에 버리거나 경고
				print("WARNING: 가방에 자리가 없어 기존 장비를 교체할 수 없습니다.")
				return false
		
		# 아이템 소유권 이전
		if dragged_item.parent_inventory != self:
			dragged_item.reparent(equipment_items_node)
			dragged_item.parent_inventory = self
			
		snap_item_to_grid(dragged_item, target_slot_id)
		return true
	return false

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

# [신규] 장비 슬롯 시각화 업데이트
func _refresh_equipment_visuals():
	# 기존에 생성된 아이템 노드 제거
	for item in items:
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
			var item_id = item_info["id"]
			var item_node = _spawn_item_node(item_id)
			snap_item_to_grid(item_node, i)

# 아이템 노드 생성을 위한 헬퍼
func _spawn_item_node(item_id: String):
	var item_scene = preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item = item_scene.instantiate()
	item.id = item_id
	item.parent_inventory = self
	equipment_items_node.add_child(item)
	return item

# --- 시그널 핸들러 ---
func _on_gold_changed(new_gold: int, _delta: int):
	update_gold_display(new_gold)

func _on_close_button_pressed():
	hide_screen()
	emit_signal("inventory_closed")

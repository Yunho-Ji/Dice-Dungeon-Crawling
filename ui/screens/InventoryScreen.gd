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
var slot_background = null 
var slot_icon = null       

# [신규] 드롭 중복 처리 방지 플래그
var is_processing_drop := false

# [신규] Apeloot 인벤토리 식별자
var id = "equipment_screen"

func _enter_tree():
	Apeloot.inventory_refs[id] = self

func _exit_tree():
	if Apeloot.inventory_refs.get(id) == self:
		Apeloot.inventory_refs.erase(id)

func get_global_rect() -> Rect2:
	var section = get_node_or_null("CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection")
	if section:
		var rect = section.get_global_rect()
		if rect.size.x > 0:
			return rect
	return main_panel.get_global_rect() if main_panel else Rect2()

func calculate_item_position(_item, slot_id: int) -> Vector2:
	if slot_id >= 0 and slot_id < all_slots.size():
		var slot = all_slots[slot_id]
		return slot.global_position
	return get_viewport().get_mouse_position()

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)
	SignalBus.connect("gold_changed", _on_gold_changed)
	self.visibility_changed.connect(_on_visibility_changed)
	
	_setup_equipment_slots()
	
	# 데이터 복원
	if inventory_interface:
		inventory_interface.initialize_inventory(PlayerManager.inventory_data)
		
	hide_screen()

func _on_visibility_changed():
	if self.visible:
		update_gold_display()
		_refresh_equipment_visuals()
		_process_pending_items()
		
		# [수정] 타일 크기에 맞게 가방 크기 조정
		var tile_size = Apeloot.INVENTORY_ITEM_SIZE.x
		inventory_interface.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
		
		var is_combat = GameManager.current_game_phase == GameManager.GamePhase.COMBAT
		for slot in all_slots:
			if slot:
				slot.can_drag = not is_combat
	else:
		_save_to_player_manager()

func _save_to_player_manager():
	if is_instance_valid(inventory_interface):
		PlayerManager.inventory_data = inventory_interface.item_states.duplicate(true)

func _process_pending_items():
	if not is_instance_valid(inventory_interface): return
	var pending = PlayerManager.consume_pending_items()
	for item_id in pending:
		var new_item = inventory_interface.spawn_item(item_id)
		if not inventory_interface.try_fit_and_place(new_item):
			new_item.queue_free()
			PlayerManager.add_pending_item(item_id)

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
		
		# 레이블 추가 (약식)
		if slot.get_child_count() == 0:
			var label = Label.new()
			label.text = _get_slot_name_korean(key)
			label.add_theme_font_size_override("font_size", 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(label)

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

func get_slot_by_index(index: int):
	if index >= 0 and index < all_slots.size(): return all_slots[index]
	return null

func get_item_at_slot(index: int):
	var slot = get_slot_by_index(index)
	return slot.occupying_item if slot else null

func find_slot_at_position(_pos: Vector2) -> int:
	var global_pos = get_viewport().get_mouse_position()
	for i in range(all_slots.size()):
		if all_slots[i].get_global_rect().has_point(global_pos):
			return i
	return -1

func can_place_item(item, slot_id: int) -> bool:
	if slot_id == -1: return false
	if GameManager.current_game_phase == GameManager.GamePhase.COMBAT: return false
	
	var slot_key = slot_to_key.get(slot_id, "")
	var item_data = Apeloot.items.get(item.id, {})
	var equip_type = item_data.get("equip_type", "none")
	
	var type_match = false
	match slot_key:
		"head": type_match = (equip_type == "head")
		"top": type_match = (equip_type == "top")
		"bottom": type_match = (equip_type == "bottom")
		"shoes": type_match = (equip_type == "shoes")
		"left_hand", "right_hand": type_match = (equip_type in ["weapon", "shield"])
		"accessory_1", "accessory_2", "accessory_3", "accessory_4": type_match = (equip_type == "accessory")
	
	if not type_match: return false
	return PlayerManager.can_equip_item(item_data)

func handle_item_drop(dragged_item, target_slot_id: int):
	if is_processing_drop: return false
	is_processing_drop = true
	
	var success = false
	if can_place_item(dragged_item, target_slot_id):
		# ... (기존 로직 유지) ...
		var slot_key = slot_to_key[target_slot_id]
		var item_data = {
			"id": dragged_item.id,
			"rarity": dragged_item.rarity,
			"stats": dragged_item.stats.duplicate(),
			"price": dragged_item.price,
			"instance_id": dragged_item.instance_id
		}
		
		var target_slot = all_slots[target_slot_id]
		var old_item_node = target_slot.occupying_item
		
		if old_item_node:
			if not inventory_interface.try_fit_and_place(old_item_node):
				is_processing_drop = false
				return false
		
		PlayerManager.equip_item(slot_key, item_data)
		if dragged_item.parent_inventory != self:
			dragged_item.reparent(equipment_items_node)
			dragged_item.parent_inventory = self
		
		dragged_item.location_tag = "equipment"
		snap_item_to_grid(dragged_item, target_slot_id)
		
		if dragged_item.has_node("ItemTexture"):
			dragged_item.get_node("ItemTexture").end_drag()
		success = true

	get_tree().create_timer(0.05).timeout.connect(func(): is_processing_drop = false)
	return success

func snap_item_to_grid(item, slot_id: int):
	var slot = all_slots[slot_id]
	item.global_position = slot.global_position + (slot.size / 2.0) - (item.get_node("ItemTexture").size / 2.0)
	item.previous_center_slot = slot_id
	if not items.has(item): items.append(item)
	slot.occupying_item = item
	slot.full = true

func get_rotated_pattern(_item):
	# 장비창은 격자 기반이 아니므로 모든 아이템을 1x1 크기로 간주하여 처리합니다.
	return [[1]]

func remove_item(item):
	var slot_id = item.previous_center_slot
	if slot_id != -1:
		all_slots[slot_id].occupying_item = null
		all_slots[slot_id].full = false
		PlayerManager.unequip_item(slot_to_key[slot_id])
	items.erase(item)
	if is_instance_valid(item): item.queue_free()

func deregister_item(item):
	var slot_id = item.previous_center_slot
	if slot_id != -1:
		all_slots[slot_id].occupying_item = null
		all_slots[slot_id].full = false
		PlayerManager.unequip_item(slot_to_key[slot_id])
	items.erase(item)

func show_screen(): self.visible = true
func hide_screen(): self.visible = false
func update_gold_display(gold_amount: int = -1):
	if gold_amount == -1: gold_amount = EconomyManager.get_gold()
	gold_label.text = "소지 골드: %d G" % gold_amount

func _refresh_equipment_visuals():
	for item in items.duplicate():
		if is_instance_valid(item): item.queue_free()
	items.clear()
	for slot in all_slots:
		slot.occupying_item = null
		slot.full = false
	
	for i in range(all_slots.size()):
		var key = slot_to_key[i]
		var item_info = PlayerManager.equipment.get(key)
		if item_info and item_info.has("id"):
			var item_node = _spawn_item_node_with_data(item_info)
			snap_item_to_grid(item_node, i)

func _spawn_item_node_with_data(item_data: Dictionary):
	var item_scene = preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item = item_scene.instantiate()
	item.id = item_data["id"]
	if item_data.has("instance_id"): item.instance_id = item_data["instance_id"]
	if item_data.has("rarity"): item.rarity = item_data["rarity"]
	if item_data.has("stats"): item.stats = item_data["stats"].duplicate()
	if item_data.has("price"): item.price = item_data["price"]
	item.parent_inventory = self
	equipment_items_node.add_child(item)
	return item

func try_fit_and_place(item) -> bool:
	if item.previous_center_slot != -1:
		snap_item_to_grid(item, item.previous_center_slot)
		var key = slot_to_key.get(item.previous_center_slot)
		if key:
			var item_data = {"id": item.id, "rarity": item.rarity, "stats": item.stats.duplicate(), "price": item.price, "instance_id": item.instance_id}
			PlayerManager.equip_item(key, item_data)
		return true
	return false

func _on_gold_changed(new_gold: int, _delta: int): update_gold_display(new_gold)
func _on_close_button_pressed():
	hide_screen()
	emit_signal("inventory_closed")

# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리 및 장비를 표시하는 UI입니다.
extends CanvasLayer

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed

# --- 노드 참조 ---
@onready var main_panel = $MainPanel
@onready var inventory_interface: CustomInventoryGrid = $MainPanel/VBox/MainVBox/InventorySection/InventoryInterface
@onready var gold_label = $MainPanel/VBox/Footer/GoldLabel
@onready var close_button = $MainPanel/VBox/Header/CloseButton

# 장비 슬롯 참조
@onready var head_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/HeadSlot
@onready var top_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/TopSlot
@onready var bottom_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/BottomSlot
@onready var shoes_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/ShoesSlot
@onready var left_hand_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/LeftHandSlot
@onready var right_hand_slot = $MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/RightHandSlot
@onready var acc_slots = [
	$MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/AccessoryGroup/Acc1,
	$MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/AccessoryGroup/Acc2,
	$MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/AccessoryGroup/Acc3,
	$MainPanel/VBox/MainVBox/EquipmentSection/SilhouetteContainer/AccessoryGroup/Acc4
]
@onready var trash_bin = %TrashBin

# --- 장비 시스템 관련 변수 ---
var slot_to_key = {}
var all_slots = []

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)
	
	if SignalBus and not SignalBus.gold_changed.is_connected(_on_gold_changed):
		SignalBus.gold_changed.connect(_on_gold_changed)
		
	self.visibility_changed.connect(_on_visibility_changed)
	
	_setup_equipment_slots()
	
	# 데이터 연결
	if inventory_interface and PlayerManager:
		inventory_interface.inventory_data = PlayerManager.inventory_data
		
	hide_screen()

func _on_visibility_changed():
	if self.visible:
		update_gold_display()
		_refresh_equipment_visuals()
		_process_pending_items()
		
		# 인벤토리 UI 갱신 강제 호출
		if inventory_interface:
			inventory_interface.refresh_ui()

func _process_pending_items():
	if not PlayerManager: return
	var pending = PlayerManager.consume_pending_items()
	for item_id in pending:
		if not InventoryManager.try_add_item(item_id):
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
	
	var allowed_types_map = {
		"head": ["head"],
		"top": ["top"],
		"bottom": ["bottom"],
		"shoes": ["shoes"],
		"left_hand": ["weapon", "shield", "left_hand", "two_hand"],
		"right_hand": ["weapon", "shield", "right_hand", "two_hand"],
		"accessory_1": ["accessory"],
		"accessory_2": ["accessory"],
		"accessory_3": ["accessory"],
		"accessory_4": ["accessory"]
	}
	
	for i in range(all_slots.size()):
		var slot = all_slots[i]
		var key = keys[i]
		slot_to_key[i] = key
		
		# [수정] 속성 설정 시 안전성 강화
		if slot.has_method("set"):
			slot.set("slot_key", key)
			slot.set("allowed_types", allowed_types_map.get(key, []))
		
		# 레이블 추가 (이미 있으면 무시)
		var existing_label = null
		for child in slot.get_children():
			if child is Label:
				existing_label = child
				break
				
		if not existing_label:
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

func show_screen():
	self.visible = true

func hide_screen():
	self.visible = false

func update_gold_display(gold_amount: int = -1):
	if gold_amount == -1 and EconomyManager: 
		gold_amount = EconomyManager.get_gold()
	gold_label.text = "소지 골드: %d G" % gold_amount

func _refresh_equipment_visuals():
	if not PlayerManager: return
	for slot in all_slots:
		var eq_slot = slot as CustomEquipmentSlotUI
		if not eq_slot: continue
		
		if eq_slot.occupying_item_ui:
			eq_slot.occupying_item_ui.queue_free()
			eq_slot.occupying_item_ui = null
		
		var item_data = PlayerManager.equipment.get(eq_slot.slot_key)
		if item_data and item_data.has("id"):
			var inv_item = InventoryItem.new()
			inv_item.id = item_data["id"]
			
			var item_ui_scene = load("res://ui/inventory/DraggableItemUI.tscn")
			if item_ui_scene:
				var item_ui = item_ui_scene.instantiate() as DraggableItemUI
				eq_slot.add_child(item_ui)
				item_ui.setup(inv_item)
				eq_slot.occupying_item_ui = item_ui

func _on_gold_changed(new_gold: int, _delta: int):
	update_gold_display(new_gold)

func _on_close_button_pressed():
	hide_screen()
	inventory_closed.emit()

extends PanelContainer

signal closed

# UI Components
var target_slot_panel: PanelContainer
var dice_list_container: HBoxContainer
var result_label: Label
var enchant_button: Button
var target_item_label: Label

# Data
var current_target_item: InventoryItem = null # 현재 슬롯에 올라간 아이템 데이터
var selected_dice_index: int = -1 # 선택된 주사위 인덱스
var selected_dice_sides: int = 0

func _ready():
	custom_minimum_size = Vector2(600, 500)
	
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "--- 아이템 강화 (주사위 소모) ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# 1. Target Item Slot (Drop Zone)
	target_slot_panel = PanelContainer.new()
	target_slot_panel.custom_minimum_size = Vector2(0, 100)
	target_slot_panel.set_script(load("res://ui/inventory/InventorySlotUI.gd"))
	
	var slot_label = Label.new()
	slot_label.text = "강화할 장비를 이곳에 드래그하세요"
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_slot_panel.add_child(slot_label)
	main_vbox.add_child(target_slot_panel)
	
	# 드롭 로직 오버라이드
	target_slot_panel.set_script(null) # 다시 초기화
	target_slot_panel.set_script(load("res://ui/screens/EnchantScreen.gd").EnchantSlot)
	
	target_item_label = Label.new()
	target_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(target_item_label)
	
	# 2. Dice Selection
	var dice_label = Label.new()
	dice_label.text = "소모할 주사위 선택:"
	main_vbox.add_child(dice_label)
	
	dice_list_container = HBoxContainer.new()
	dice_list_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(dice_list_container)
	
	_refresh_dice_list()
	
	# 3. Action Button
	enchant_button = Button.new()
	enchant_button.text = "강화 시작 (주사위 소모)"
	enchant_button.disabled = true
	enchant_button.pressed.connect(_on_enchant_pressed)
	main_vbox.add_child(enchant_button)
	
	# 4. Result
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(result_label)
	
	# Close
	var close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

# 내부 클래스로 드롭 슬롯 정의 (순환 참조 방지)
class EnchantSlot extends PanelContainer:
	var parent_screen: Node
	
	func _can_drop_data(_at_position, data):
		return data is Dictionary and data.has("item")
		
	func _drop_data(_at_position, data):
		var item = data["item"] as InventoryItem
		parent_screen.handle_item_drop(item, data.get("source_node"))

func handle_item_drop(item: InventoryItem, source_node: Node):
	if current_target_item:
		_return_item_to_inventory(current_target_item)
	
	# 기존 위치에서 제거
	if source_node:
		var source_parent = source_node.get_parent()
		if source_parent.name == "ItemsContainer":
			PlayerManager.inventory_data.remove_item(item)
	
	current_target_item = item
	target_item_label.text = DataManager.get_item(item.id).get("name", "Unknown Item")
	
	# UI 표시용 노드 생성 (임시)
	for child in target_slot_panel.get_children():
		if child is DraggableItemUI: child.queue_free()
		
	var item_ui = preload("res://ui/inventory/DraggableItemUI.tscn").instantiate() as DraggableItemUI
	target_slot_panel.add_child(item_ui)
	item_ui.setup(item)
	item_ui.position = (target_slot_panel.size / 2.0) - (item_ui.size / 2.0)
	
	_update_enchant_button()

func _refresh_dice_list():
	for c in dice_list_container.get_children():
		c.queue_free()
		
	var pool = DiceManager.get_player_dice_pool()
	for i in range(pool.size()):
		var sides = pool[i]
		var btn = Button.new()
		btn.text = "D%d" % sides
		btn.toggle_mode = true
		btn.pressed.connect(_on_dice_selected.bind(i, sides, btn))
		dice_list_container.add_child(btn)

func _on_dice_selected(idx: int, sides: int, btn: Button):
	selected_dice_index = idx
	selected_dice_sides = sides
	for child in dice_list_container.get_children():
		if child != btn:
			child.set_pressed_no_signal(false)
	_update_enchant_button()

func _update_enchant_button():
	enchant_button.disabled = (current_target_item == null or selected_dice_index == -1)

func _return_item_to_inventory(item: InventoryItem):
	PlayerManager.inventory_data.add_item(item.id)
	current_target_item = null
	target_item_label.text = ""

func _on_enchant_pressed():
	if not current_target_item or selected_dice_index == -1: return
	
	enchant_button.disabled = true
	result_label.text = "주사위를 굴리는 중..."
	await get_tree().create_timer(1.0).timeout
	
	var roll_result = randi_range(1, selected_dice_sides)
	result_label.text = "주사위 결과: %d!" % roll_result
	await get_tree().create_timer(0.5).timeout
	
	var enchant_manager = get_node("/root/EnchantManager")
	var item_def = DataManager.get_item(current_target_item.id)
	
	# [임시] 강화 데이터 구성
	var enchant_data = {
		"name": item_def.get("name", ""),
		"grade": 0, # TODO: 등급 매핑
		"stats": item_def.get("stats", {})
	}
	
	var success = enchant_manager.enchant_item(enchant_data, roll_result)
	if success:
		result_label.text += "
강화 성공!"
		DiceManager.player_dice_pool.remove_at(selected_dice_index)
		_refresh_dice_list()
		selected_dice_index = -1
	else:
		result_label.text += "
강화 실패..."
		DiceManager.player_dice_pool.remove_at(selected_dice_index)
		_refresh_dice_list()
		selected_dice_index = -1

	enchant_button.disabled = false
	_update_enchant_button()

func _on_close_pressed():
	if current_target_item:
		_return_item_to_inventory(current_target_item)
	closed.emit()
	queue_free()

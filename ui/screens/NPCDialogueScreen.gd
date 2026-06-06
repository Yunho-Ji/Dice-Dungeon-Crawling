extends PanelContainer

signal closed(action_type: int, param)

var npc_data: NPCData
var portrait_rect: TextureRect
var name_label: Label
var dialogue_label: Label
var button_container: VBoxContainer
var npc_grid_area: PanelContainer
var player_inventory_area: VBoxContainer
var interaction_hbox: HBoxContainer
var main_hbox: HBoxContainer

var left_vbox: VBoxContainer
var center_vbox: VBoxContainer
var top_header: HBoxContainer
var header_label: Label

var player_inventory_interface: CustomInventoryGrid = null
var player_gold_label: Label = null

func _ready():
	var viewport_size = get_viewport_rect().size
	custom_minimum_size = Vector2(min(viewport_size.x * 0.9, 1100), min(viewport_size.y * 0.85, 600))
	
	var layout_vbox = VBoxContainer.new()
	layout_vbox.add_theme_constant_override("separation", 10)
	add_child(layout_vbox)
	
	top_header = HBoxContainer.new()
	top_header.visible = false
	layout_vbox.add_child(top_header)
	
	header_label = Label.new()
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_font_size_override("font_size", 20)
	top_header.add_child(header_label)
	
	var back_btn = Button.new()
	back_btn.text = "대화로 돌아가기"
	back_btn.pressed.connect(set_transaction_mode.bind(false))
	top_header.add_child(back_btn)
	
	main_hbox = HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 20)
	layout_vbox.add_child(main_hbox)
	
	left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(250, 0)
	main_hbox.add_child(left_vbox)
	
	var portrait_panel = PanelContainer.new()
	portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(portrait_panel)
	
	portrait_rect = TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_panel.add_child(portrait_rect)
	
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	left_vbox.add_child(name_label)
	
	center_vbox = VBoxContainer.new()
	center_vbox.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(center_vbox)
	
	var dialogue_panel = PanelContainer.new()
	dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.text = "안녕하세요. 무엇을 도와드릴까요?"
	dialogue_panel.add_child(dialogue_label)
	center_vbox.add_child(dialogue_panel)
	
	button_container = VBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 180)
	button_container.alignment = BoxContainer.ALIGNMENT_END
	center_vbox.add_child(button_container)
	
	interaction_hbox = HBoxContainer.new()
	interaction_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_hbox.add_theme_constant_override("separation", 15)
	main_hbox.add_child(interaction_hbox)
	
	var npc_vbox = VBoxContainer.new()
	npc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_hbox.add_child(npc_vbox)
	
	var npc_label = Label.new()
	npc_label.text = "--- 상점 / 시설 ---"
	npc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_vbox.add_child(npc_label)
	
	npc_grid_area = PanelContainer.new()
	npc_grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0, 0, 0, 0.2)
	npc_grid_area.add_theme_stylebox_override("panel", empty_style)
	npc_vbox.add_child(npc_grid_area)
	
	player_inventory_area = VBoxContainer.new()
	player_inventory_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_inventory_area.visible = false
	interaction_hbox.add_child(player_inventory_area)

func setup(data: NPCData):
	npc_data = data
	name_label.text = data.npc_name
	header_label.text = "[ 거래 중: %s ]" % data.npc_name
	dialogue_label.text = data.get_random_greeting()
	if data.portrait_path != "" and FileAccess.file_exists(data.portrait_path):
		portrait_rect.texture = load(data.portrait_path)
	_create_option_buttons()

func set_transaction_mode(active: bool):
	top_header.visible = active
	left_vbox.visible = not active
	center_vbox.visible = not active
	if not active:
		show_player_inventory(false)
		set_grid_content(null)

func _create_option_buttons():
	for child in button_container.get_children():
		child.queue_free()
	if not npc_data: return
	for option in npc_data.options:
		var btn = Button.new()
		btn.text = option.get("text", "Unknown")
		btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(_on_option_selected.bind(option))
		button_container.add_child(btn)
	var exit_btn = Button.new()
	exit_btn.text = "대화를 마친다 (나가기)"
	exit_btn.custom_minimum_size = Vector2(0, 40)
	exit_btn.pressed.connect(_on_exit_pressed)
	button_container.add_child(exit_btn)

func set_grid_content(content_node: Control):
	for child in npc_grid_area.get_children(): child.queue_free()
	if content_node:
		var tile_size = 40
		content_node.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
		content_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		npc_grid_area.add_child(content_node)

func show_player_inventory(show: bool):
	player_inventory_area.visible = show
	if not show:
		for child in player_inventory_area.get_children(): child.queue_free()
		player_inventory_interface = null
		return
	
	if player_inventory_interface: return
	
	var bag_label = Label.new()
	bag_label.text = "--- 내 가방 (6x10) ---"
	bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_inventory_area.add_child(bag_label)
	
	var grid_scene = load("res://ui/inventory/CustomInventoryGrid.tscn")
	if grid_scene:
		player_inventory_interface = grid_scene.instantiate() as CustomInventoryGrid
		player_inventory_interface.inventory_data = PlayerManager.inventory_data if PlayerManager else null
		
		var tile_size = 40
		player_inventory_interface.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
		player_inventory_interface.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		player_inventory_interface.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		player_inventory_area.add_child(player_inventory_interface)
		
		# 대기열 처리
		if PlayerManager and InventoryManager:
			var pending = PlayerManager.consume_pending_items()
			for item_id in pending:
				if not InventoryManager.try_add_item(item_id):
					PlayerManager.add_pending_item(item_id)
	
	player_gold_label = Label.new()
	if EconomyManager:
		player_gold_label.text = "소지 골드: %d G" % EconomyManager.get_gold()
	player_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_gold_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	player_inventory_area.add_child(player_gold_label)

func _on_option_selected(option: Dictionary):
	var type = option.get("type", 0) # NPCData.FunctionType.EXIT
	var param = option.get("param", null)
	# NPCData.FunctionType constants are needed here or use raw ints
	# Assume type 1: TALK, type 0: EXIT for safety
	if type == 1:
		dialogue_label.text = npc_data.get_random_talk()
	elif type == 0:
		_on_exit_pressed()
	else:
		closed.emit(type, param)

func _on_exit_pressed():
	closed.emit(0, null) # 0 for EXIT
	queue_free()

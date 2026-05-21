extends PanelContainer

signal closed(action_type, param)

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

var player_inventory_interface: Control = null
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
		var tile_size = Apeloot.INVENTORY_ITEM_SIZE.x
		content_node.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
		content_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		npc_grid_area.add_child(content_node)
		_disable_internal_scroll(content_node)

func show_player_inventory(show: bool):
	player_inventory_area.visible = show
	if not show:
		_save_inventory_data()
		for child in player_inventory_area.get_children(): child.queue_free()
		player_inventory_interface = null
		return
	
	if player_inventory_interface: return
	
	var bag_label = Label.new()
	bag_label.text = "--- 내 가방 (6x10) ---"
	bag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_inventory_area.add_child(bag_label)
	
	var inv_script = load("res://addons/apeloot/inventory/grid_inventory/inventory_interface.gd")
	player_inventory_interface = PanelContainer.new()
	player_inventory_interface.set_script(inv_script)
	player_inventory_interface.id = "player_inventory"
	player_inventory_interface.slot_count = 60
	player_inventory_interface.columns = 10
	
	var tile_size = Apeloot.INVENTORY_ITEM_SIZE.x
	player_inventory_interface.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
	player_inventory_interface.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	player_inventory_interface.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_inventory_area.add_child(player_inventory_interface)
	
	# 데이터 로드
	player_inventory_interface.initialize_inventory(PlayerManager.inventory_data)
	
	# 대기열 처리
	var pending = PlayerManager.consume_pending_items()
	for item_id in pending:
		var new_item = player_inventory_interface.spawn_item(item_id)
		if not player_inventory_interface.try_fit_and_place(new_item):
			new_item.queue_free()
			PlayerManager.add_pending_item(item_id)
	
	call_deferred("_disable_internal_scroll", player_inventory_interface)
	
	player_gold_label = Label.new()
	player_gold_label.text = "소지 골드: %d G" % EconomyManager.get_gold()
	player_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_gold_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
	player_inventory_area.add_child(player_gold_label)

func _disable_internal_scroll(grid_node: Control):
	if not is_instance_valid(grid_node): return
	var transparent_style = StyleBoxEmpty.new()
	grid_node.add_theme_stylebox_override("panel", transparent_style)
	for child in grid_node.get_children():
		if child is ScrollContainer:
			child.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			child.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			child.get_v_scroll_bar().visible = false
			child.get_h_scroll_bar().visible = false
			var inner_panel = child.get_child(0)
			if inner_panel is PanelContainer: inner_panel.add_theme_stylebox_override("panel", transparent_style)
			if grid_node.get("columns") and grid_node.get("slot_count"):
				var cols = grid_node.columns
				var rows = ceil(float(grid_node.slot_count) / cols)
				var tile_size = Apeloot.INVENTORY_ITEM_SIZE.x
				grid_node.custom_minimum_size = Vector2(cols * tile_size, rows * tile_size)
			break

func _save_inventory_data():
	if player_inventory_interface and is_instance_valid(player_inventory_interface):
		PlayerManager.inventory_data = player_inventory_interface.item_states.duplicate(true)

func _on_option_selected(option: Dictionary):
	var type = option.get("type", NPCData.FunctionType.EXIT)
	var param = option.get("param", null)
	match type:
		NPCData.FunctionType.TALK: dialogue_label.text = npc_data.get_random_talk()
		NPCData.FunctionType.EXIT: _on_exit_pressed()
		_: emit_signal("closed", type, param)

func _on_exit_pressed():
	_save_inventory_data()
	emit_signal("closed", NPCData.FunctionType.EXIT, null)
	queue_free()

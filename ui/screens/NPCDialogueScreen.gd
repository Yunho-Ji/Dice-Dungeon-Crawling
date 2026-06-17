extends CanvasLayer

# NPCDialogueScreen.gd
# 중앙 NPC 초상화, 하단 대화창/선택지 기반의 대화 시스템 (해상도 최적화 버전)

signal closed(action_type: int, param)

var npc_data: NPCData
var portrait_rect: TextureRect
var name_label: Label
var dialogue_label: Label
var button_container: VBoxContainer
var npc_grid_area: PanelContainer
var interaction_hbox: HBoxContainer
var bottom_panel: PanelContainer
var main_layout: Control
var background_rect: ColorRect # 마을 지도를 가릴 불투명 배경

func _ready():
	# CanvasLayer이므로 layer 값을 인벤토리(보통 1)보다 높게 설정하여 우선순위 확보
	layer = 10
	_ensure_ui_initialized()

func _ensure_ui_initialized():
	if main_layout: return # 이미 초기화됨
	_setup_ui_manually()

func _setup_ui_manually():
	if background_rect: return
	
	background_rect = ColorRect.new()
	background_rect.color = Color(0.05, 0.07, 0.1, 1.0) # 어두운 남색 계열의 불투명 배경
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background_rect)
	
	main_layout = Control.new()
	main_layout.name = "MainLayout"
	main_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_layout)
	
	# 1. 상점 구역 (거래 모드에서만 활성화)
	interaction_hbox = HBoxContainer.new()
	interaction_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	interaction_hbox.offset_left = 20
	interaction_hbox.offset_top = 20
	interaction_hbox.offset_right = -20
	interaction_hbox.offset_bottom = -220
	interaction_hbox.visible = false
	main_layout.add_child(interaction_hbox)
	
	var npc_vbox = VBoxContainer.new()
	npc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_hbox.add_child(npc_vbox)
	
	var shop_header = HBoxContainer.new()
	shop_header.add_theme_constant_override("separation", 10)
	npc_vbox.add_child(shop_header)
	
	var npc_label = Label.new()
	npc_label.text = "--- 상점 / 시설 ---"
	npc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_header.add_child(npc_label)
	
	var back_btn = Button.new()
	back_btn.text = " 돌아가기 "
	back_btn.pressed.connect(set_transaction_mode.bind(false))
	shop_header.add_child(back_btn)
	
	npc_grid_area = PanelContainer.new()
	npc_grid_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shop_style = StyleBoxFlat.new()
	shop_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	shop_style.border_width_left = 2
	shop_style.border_width_top = 2
	shop_style.border_width_right = 2
	shop_style.border_width_bottom = 2
	shop_style.border_color = Color(0.35, 0.4, 0.5, 1.0)
	shop_style.corner_radius_top_left = 8
	shop_style.corner_radius_top_right = 8
	shop_style.corner_radius_bottom_right = 8
	shop_style.corner_radius_bottom_left = 8
	npc_grid_area.add_theme_stylebox_override("panel", shop_style)
	npc_vbox.add_child(npc_grid_area)
	
	# 2. NPC 초상화
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(400, 500)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.anchor_left = 0.5
	portrait_rect.anchor_top = 0.5
	portrait_rect.anchor_right = 0.5
	portrait_rect.anchor_bottom = 0.5
	portrait_rect.offset_top = -50
	portrait_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	portrait_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_layout.add_child(portrait_rect)
	
	# 3. 하단 대화창 패널
	bottom_panel = PanelContainer.new()
	bottom_panel.custom_minimum_size = Vector2(800, 180)
	bottom_panel.anchor_left = 0.5
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 0.5
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = -400
	bottom_panel.offset_top = -200
	bottom_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var dialogue_style = StyleBoxFlat.new()
	dialogue_style.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	dialogue_style.border_width_top = 4
	dialogue_style.border_color = Color(0.45, 0.35, 0.25, 1.0)
	dialogue_style.content_margin_left = 40
	dialogue_style.content_margin_right = 40
	bottom_panel.add_theme_stylebox_override("panel", dialogue_style)
	main_layout.add_child(bottom_panel)
	
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 50)
	bottom_panel.add_child(bottom_hbox)
	
	# 대화 텍스트 영역
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.size_flags_stretch_ratio = 2.5
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hbox.add_child(text_vbox)
	
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	text_vbox.add_child(name_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	text_vbox.add_child(spacer)
	
	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 18)
	dialogue_label.text = "..."
	text_vbox.add_child(dialogue_label)
	
	# 선택지 버튼 영역
	button_container = VBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 6)
	bottom_hbox.add_child(button_container)

func setup(data: NPCData):
	npc_data = data
	_ensure_ui_initialized()
	name_label.text = data.npc_name
	dialogue_label.text = data.get_random_greeting()
	if data.portrait_path != "" and FileAccess.file_exists(data.portrait_path):
		portrait_rect.texture = load(data.portrait_path)
	_create_option_buttons()

func set_transaction_mode(active: bool):
	interaction_hbox.visible = active
	if is_instance_valid(bottom_panel):
		bottom_panel.visible = not active
	
	if active:
		main_layout.anchor_right = 0.0
		main_layout.offset_right = 700 
		portrait_rect.modulate.a = 0.3
		dialogue_label.text = "어떤 물건을 찾으시나요?"
		
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.ui_manager:
			gm.ui_manager.show_screen(UIManager.Screen.INVENTORY)
			var inv_node = gm.ui_manager.get_screen_node(UIManager.Screen.INVENTORY)
			if inv_node and inv_node is CanvasLayer:
				inv_node.layer = self.layer + 1
	else:
		main_layout.anchor_right = 1.0
		main_layout.offset_right = 0
		portrait_rect.modulate.a = 1.0
		dialogue_label.text = npc_data.get_random_greeting() if npc_data else "..."
		
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.ui_manager:
			var inv_node = gm.ui_manager.get_screen_node(UIManager.Screen.INVENTORY)
			if inv_node and inv_node is CanvasLayer:
				inv_node.layer = 100
			gm.ui_manager.show_screen(UIManager.Screen.NONE)
		set_grid_content(null)

func _create_option_buttons():
	if not button_container: _ensure_ui_initialized()
	for child in button_container.get_children():
		child.queue_free()
	
	if not npc_data: return
	
	for option in npc_data.options:
		var btn = Button.new()
		btn.text = " > " + option.get("text", "대화")
		btn.custom_minimum_size = Vector2(220, 40)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_option_selected.bind(option))
		button_container.add_child(btn)
		
	var exit_btn = Button.new()
	exit_btn.text = " > 대화를 마친다"
	exit_btn.custom_minimum_size = Vector2(220, 40)
	exit_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	exit_btn.pressed.connect(_on_exit_pressed)
	button_container.add_child(exit_btn)

func set_grid_content(content_node: Control):
	if not npc_grid_area: _ensure_ui_initialized()
	for child in npc_grid_area.get_children(): child.queue_free()
	if content_node:
		var tile_size = 40
		content_node.custom_minimum_size = Vector2(tile_size * 10, tile_size * 6)
		content_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		npc_grid_area.add_child(content_node)
		npc_grid_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		npc_grid_area.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_option_selected(option: Dictionary):
	var type = option.get("type", 0)
	var param = option.get("param", null)
	
	if type == NPCData.FunctionType.TALK:
		dialogue_label.text = npc_data.get_random_talk()
	else:
		closed.emit(type, param)

func show_player_inventory(_show: bool):
	pass

func _on_exit_pressed():
	closed.emit(NPCData.FunctionType.EXIT, null)
	queue_free()

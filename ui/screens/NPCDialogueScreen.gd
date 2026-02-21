extends PanelContainer

signal closed(action_type, param) # 대화 종료 시 수행할 액션 전달

var npc_data: NPCData
var portrait_rect: TextureRect
var name_label: Label
var dialogue_label: Label
var button_container: VBoxContainer
var close_button: Button

func _ready():
	custom_minimum_size = Vector2(800, 500)
	
	var main_hbox = HBoxContainer.new()
	add_child(main_hbox)
	
	# [좌측] NPC 초상화 영역
	var portrait_panel = PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(portrait_panel)
	
	portrait_rect = TextureRect.new()
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # 크기 조정 무시 (컨테이너에 맞춤)
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_panel.add_child(portrait_rect)
	
	# [우측] 대화 및 선택지 영역
	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content_vbox)
	
	# 이름표
	var name_panel = PanelContainer.new()
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_panel.add_child(name_label)
	content_vbox.add_child(name_panel)
	
	# 대사창
	var dialogue_panel = PanelContainer.new()
	dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(0, 100)
	dialogue_panel.add_child(dialogue_label)
	content_vbox.add_child(dialogue_panel)
	
	# 선택지 버튼들
	button_container = VBoxContainer.new()
	button_container.custom_minimum_size = Vector2(0, 200)
	button_container.alignment = BoxContainer.ALIGNMENT_END
	content_vbox.add_child(button_container)

func setup(data: NPCData):
	npc_data = data
	name_label.text = data.npc_name
	dialogue_label.text = data.get_random_greeting()
	
	if data.portrait_path != "":
		if FileAccess.file_exists(data.portrait_path):
			portrait_rect.texture = load(data.portrait_path)
		else:
			# 기본 이미지나 플레이스홀더
			pass
			
	_create_option_buttons()

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
		
	# 기본 나가기 버튼 (항상 마지막에 추가)
	var exit_btn = Button.new()
	exit_btn.text = "대화를 마친다 (나가기)"
	exit_btn.custom_minimum_size = Vector2(0, 40)
	exit_btn.pressed.connect(_on_exit_pressed)
	button_container.add_child(exit_btn)

func _on_option_selected(option: Dictionary):
	var type = option.get("type", NPCData.FunctionType.EXIT)
	var param = option.get("param", null)
	
	match type:
		NPCData.FunctionType.TALK:
			dialogue_label.text = npc_data.get_random_talk()
		NPCData.FunctionType.EXIT:
			_on_exit_pressed()
		_:
			# 기능 실행 요청 (Town.gd 등 상위에서 처리)
			emit_signal("closed", type, param)
			queue_free()

func _on_exit_pressed():
	emit_signal("closed", NPCData.FunctionType.EXIT, null)
	queue_free()

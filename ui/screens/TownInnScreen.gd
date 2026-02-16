extends PanelContainer

signal closed

@onready var save_button = $VBox/SaveButton
@onready var load_button = $VBox/LoadButton
@onready var rest_button = $VBox/RestButton
@onready var close_button = $VBox/CloseButton
@onready var message_label = $VBox/MessageLabel

func _ready():
	custom_minimum_size = Vector2(400, 300)
	
	# 기본 UI 구조 생성 (씬 파일 대신 스크립트로 구성)
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)
	
	var title = Label.new()
	title.text = "--- 여관 ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = "무엇을 도와드릴까요?"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	rest_button = Button.new()
	rest_button.name = "RestButton"
	rest_button.text = "휴식하기 (HP/MP 회복, 다음 날로)"
	rest_button.pressed.connect(_on_rest_pressed)
	vbox.add_child(rest_button)
	
	save_button = Button.new()
	save_button.name = "SaveButton"
	save_button.text = "게임 저장"
	save_button.pressed.connect(_on_save_pressed)
	vbox.add_child(save_button)
	
	load_button = Button.new()
	load_button.name = "LoadButton"
	load_button.text = "게임 불러오기"
	load_button.pressed.connect(_on_load_pressed)
	vbox.add_child(load_button)
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "나가기"
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _on_rest_pressed():
	var tm = get_node("/root/TownManager")
	var pm = get_node("/root/PlayerManager")
	
	# 1. 시간 리셋
	tm.reset_to_next_day()
	
	# 2. HP/MP 완전 회복
	if pm.current_player_stats:
		var hp = pm.current_player_stats.get_stat("health")
		var mp = pm.current_player_stats.get_stat("current_mp")
		if hp: hp.current_value = hp.computed_value
		if mp: mp.current_value = mp.computed_value
		
	message_label.text = "푹 쉬고 나니 몸이 가볍습니다! (회복 완료)"
	print("Inn: 휴식 완료. 모든 스탯 회복.")

func _on_save_pressed():
	if SaveManager.save_game_at_inn():
		message_label.text = "진행 상황이 저장되었습니다."
	else:
		message_label.text = "저장에 실패했습니다."

func _on_load_pressed():
	if SaveManager.load_game():
		message_label.text = "데이터를 불러왔습니다. (잠시 후 UI 갱신)"
		await get_tree().create_timer(0.5).timeout
		# 마을 씬을 다시 로드하여 모든 상태 반영 (가장 안전한 방법)
		get_tree().reload_current_scene()
	else:
		message_label.text = "저장된 데이터가 없습니다."

func _on_close_pressed():
	closed.emit()
	queue_free()

extends CanvasLayer

# EventPopup.gd (범용 이벤트 시스템)
# 역할: 함정, 보물상자, 제단, 성소 등 다양한 던전 이벤트를 통합 처리합니다.

signal event_completed

enum EventType { TRAP, TREASURE, ALTAR, SANCTUARY }
var current_event_type: EventType = EventType.TRAP

# --- 프리로드 ---
const DiceVisualScene = preload("res://ui/elements/DiceVisual.tscn")

@onready var panel = $EventPopup
@onready var title_label: Label = $EventPopup/MarginContainer/VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $EventPopup/MarginContainer/VBoxContainer/DescriptionLabel
@onready var visual_holder = $EventPopup/MarginContainer/VBoxContainer/DiceDisplayArea/VisualHolder
@onready var btn_force: Button = $EventPopup/MarginContainer/VBoxContainer/ButtonContainer/Option1Button
@onready var btn_disarm: Button = $EventPopup/MarginContainer/VBoxContainer/ButtonContainer/Option2Button
@onready var btn_confirm: Button = $EventPopup/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var result_label: Label = $EventPopup/MarginContainer/VBoxContainer/ResultLabel

# [신규] 사운드 재생용 노드
@onready var sfx_player = AudioStreamPlayer.new()

var trap_difficulty: int = 15
var player_agility: int = 0
var trap_bonus: int = 0
var trap_damage: int = 10
var dice_visual_node: Node2D = null

func _ready():
	# 초기화 시 결과 라벨 비움
	result_label.text = ""
	
	# 사운드 노드 추가
	if not sfx_player.get_parent():
		add_child(sfx_player)
	
	if not dice_visual_node:
		dice_visual_node = DiceVisualScene.instantiate()
		visual_holder.add_child(dice_visual_node)
		dice_visual_node.scale = Vector2(2.0, 2.0)
	
	dice_visual_node.visible = false
	
	# 버튼 시그널 연결 복구
	if not btn_force.pressed.is_connected(_on_option1_pressed):
		btn_force.pressed.connect(_on_option1_pressed)
	if not btn_disarm.pressed.is_connected(_on_option2_pressed):
		btn_disarm.pressed.connect(_on_option2_pressed)
	if not btn_confirm.pressed.is_connected(_on_confirm_pressed):
		btn_confirm.pressed.connect(_on_confirm_pressed)

func setup_event(type: EventType, difficulty: int = 15, damage: int = 10, bonus: int = 0):
	# 노드가 트리에 추가될 때까지 대기 (이미 추가되어 있다면 즉시 통과)
	if not is_inside_tree():
		await tree_entered
	
	# _ready가 완료될 때까지 대기
	if not is_node_ready():
		await ready

	print("EventPopup: Setting up event of type ", type)
	current_event_type = type
	trap_difficulty = difficulty
	trap_damage = damage
	trap_bonus = bonus
	
	# 팝업 가시성 강제 활성화
	self.visible = true
	if panel:
		panel.visible = true
	
	result_label.text = ""
	btn_force.disabled = false
	btn_disarm.disabled = false
	btn_force.visible = true
	btn_disarm.visible = true
	btn_confirm.visible = false
	if dice_visual_node: dice_visual_node.visible = false
	
	match current_event_type:
		EventType.TRAP:
			title_label.text = "위험한 함정"
			desc_label.text = "[center]교묘하게 설치된 함정입니다.\n(난이도 DC: %d)[/center]" % trap_difficulty
			btn_force.text = "강행 돌파 (HP -%d)" % trap_damage
			btn_disarm.text = "해제 시도 (1d20 + 보정 %d)" % trap_bonus
		
		EventType.TREASURE:
			title_label.text = "오래된 보물상자"
			desc_label.text = "[center]먼지가 쌓인 낡은 상자입니다.\n안에 무엇이 들어있을까요?[/center]"
			btn_force.text = "그냥 지나친다"
			btn_disarm.text = "상자를 연다"
			
		EventType.ALTAR:
			title_label.text = "피의 제단"
			desc_label.text = "[center]불길한 기운이 감도는 제단입니다.\n큰 대가를 치르면 강력한 힘을 줄 것 같습니다.[/center]"
			btn_force.text = "무시하고 떠난다"
			btn_disarm.text = "피의 공양 (HP -30, 영구 ATK+3)"
			
		EventType.SANCTUARY:
			title_label.text = "은총의 성소"
			desc_label.text = "[center]성스러운 빛이 내리쬐는 장소입니다.\n잠시 머무는 것만으로도 영혼이 정화됩니다.[/center]"
			btn_force.text = "무시하고 지나간다"
			btn_disarm.text = "은총을 받는다 (HP 회복 및 성장)"
	
	self.visible = true
	panel.visible = true

func _on_option1_pressed():
	match current_event_type:
		EventType.TRAP:
			_apply_damage(trap_damage)
			result_label.text = "함정을 몸으로 받아냈습니다!"
		EventType.TREASURE:
			result_label.text = "보물을 뒤로하고 길을 떠납니다."
		EventType.ALTAR:
			result_label.text = "위험한 거래를 거절했습니다."
		EventType.SANCTUARY:
			result_label.text = "성소를 지나쳐 모험을 계속합니다."
	
	_end_event()

func _on_confirm_pressed():
	self.visible = false
	emit_signal("event_completed")

func _on_option2_pressed():
	btn_force.disabled = true
	btn_disarm.disabled = true
	
	match current_event_type:
		EventType.TRAP: _handle_trap_logic()
		EventType.TREASURE: _handle_treasure_logic()
		EventType.ALTAR: _handle_altar_logic()
		EventType.SANCTUARY: _handle_sanctuary_logic()

func _handle_altar_logic():
	_apply_damage(30)
	result_label.text = ">> 피의 계약이 성사되었습니다. 힘이 솟구칩니다! (ATK +3)"
	result_label.modulate = Color.CRIMSON
	var player = get_node("/root/GameManager").player_node
	if player and player.current_stats:
		var atk_stat = player.current_stats.get_stat("atk")
		if atk_stat:
			# 영구 보너스이므로 베이스 수치를 올리고 신호 발생을 위해 수동 업데이트 호출
			atk_stat.base_value += 3
			player.update_hp_label() # UI 갱신 유도
	_end_event()

func _handle_sanctuary_logic():
	var dice_roll = randi_range(1, 20)
	await _play_dice_animation(dice_roll)
	_set_dice_final_result(dice_roll)
	result_label.text = ">> 성스러운 빛이 상처를 치유합니다. (HP 회복)"
	result_label.modulate = Color.SKY_BLUE
	var player = get_node("/root/GameManager").player_node
	if player and player.current_stats:
		var hp_stat = player.current_stats.get_stat("health")
		if hp_stat:
			# 현재 체력을 최대 체력(computed_value)을 넘지 않게 40 회복
			hp_stat.current_value = mini(hp_stat.computed_value, hp_stat.current_value + 40)
			player.update_hp_label() # UI 갱신
	_end_event()

func _handle_trap_logic():
	var dice_roll = randi_range(1, 20)
	await _play_dice_animation(dice_roll)
	var total = dice_roll + trap_bonus
	_set_dice_final_result(dice_roll)
	var result_text = "주사위: %d + 보정: %d = 합계: %d\n" % [dice_roll, trap_bonus, total]
	if total >= trap_difficulty:
		result_text += ">> 성공! 함정을 무력화했습니다."
		result_label.modulate = Color.GREEN
		_apply_damage(0)
	else:
		result_text += ">> 실패! 함정이 작동했습니다."
		result_label.modulate = Color.RED
		_apply_damage(trap_damage)
	result_label.text = result_text
	_end_event()

func _handle_treasure_logic():
	var dice_roll = randi_range(1, 20)
	await _play_dice_animation(dice_roll)
	_set_dice_final_result(dice_roll)
	if dice_roll >= 15:
		result_label.text = ">> 대박! 진귀한 보물과 주사위를 발견했습니다!"
		result_label.modulate = Color.GOLD
		get_node("/root/GameManager")._trigger_dice_reward()
	else:
		result_label.text = ">> 상자 안에서 약간의 소모품을 찾았습니다."
		result_label.modulate = Color.CYAN
	_end_event()

func _play_dice_animation(final_val: int = -1):
	dice_visual_node.visible = true
	dice_visual_node.setup(20, 1, Color("e67e22"))
	dice_visual_node.set_rolling(true)
	
	# [수정] 고속 회전 루프 제거 (애니메이션 대폭 단축)
	if final_val != -1:
		dice_visual_node.current_value = final_val
		dice_visual_node._update_number_texture()
		result_label.text = "🎲 [ %d ]" % final_val
		
		# 7프레임 시퀀스만 빠르게 재생 (약 0.2초)
		for f in range(0, 7):
			if dice_visual_node:
				dice_visual_node.sync_rolling_frame(f, true)
			await get_tree().create_timer(0.03).timeout
	
	_set_dice_final_result(final_val)

func _set_dice_final_result(val: int):
	# 숫자 및 시각 상태 최종 잠금
	dice_visual_node.current_value = val
	dice_visual_node.set_rolling(false)
	dice_visual_node._update_number_texture()
	dice_visual_node.sync_frame(6) # 마지막 7번째 프레임 강제 고정
	
	# 팝업 결과 텍스트 강조
	result_label.text = "🎲 [ %d ]" % val
	
	# 크기 강조 연출 (Tween)
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(dice_visual_node, "scale", Vector2(2.6, 2.6), 0.1)
	tween.tween_property(dice_visual_node, "scale", Vector2(2.0, 2.0), 0.2)

func _apply_damage(amount: int):
	if amount > 0:
		var player = get_node("/root/GameManager").player_node
		if player: player.take_damage(amount)

func _end_event():
	btn_force.visible = false
	btn_disarm.visible = false
	btn_confirm.visible = true

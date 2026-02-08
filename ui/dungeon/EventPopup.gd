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
var agility_bonus: int = 0
var trap_damage: int = 10
var dice_visual_node: Node2D = null

func _ready():
	self.visible = false
	result_label.text = ""
	
	# 사운드 노드 추가
	add_child(sfx_player)
	
	dice_visual_node = DiceVisualScene.instantiate()
	visual_holder.add_child(dice_visual_node)
	dice_visual_node.scale = Vector2(2.0, 2.0)
	dice_visual_node.visible = false
	
	btn_force.pressed.connect(_on_option1_pressed)
	btn_disarm.pressed.connect(_on_option2_pressed)
	btn_confirm.pressed.connect(_on_confirm_pressed)

func setup_event(type: EventType, difficulty: int = 15, damage: int = 10, bonus: int = 0):
	current_event_type = type
	trap_difficulty = difficulty
	trap_damage = damage
	agility_bonus = bonus
	
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
			btn_disarm.text = "해제 시도 (1d20 + SPD %d)" % agility_bonus
		
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
		var atk = player.current_stats.get_stat("attack_power")
		if atk: atk.base_value += 3
	_end_event()

func _handle_sanctuary_logic():
	await _play_dice_animation()
	var dice_roll = randi_range(1, 20)
	_set_dice_final_result(dice_roll)
	result_label.text = ">> 성스러운 빛이 상처를 치유합니다. (HP 회복)"
	result_label.modulate = Color.SKY_BLUE
	var player = get_node("/root/GameManager").player_node
	if player:
		player.current_health = mini(player.max_health, player.current_health + 40)
	_end_event()

func _handle_trap_logic():
	await _play_dice_animation()
	var dice_roll = randi_range(1, 20)
	var total = dice_roll + agility_bonus
	_set_dice_final_result(dice_roll)
	var result_text = "주사위: %d + 보정: %d = 합계: %d\n" % [dice_roll, agility_bonus, total]
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
	await _play_dice_animation()
	var dice_roll = randi_range(1, 20)
	_set_dice_final_result(dice_roll)
	if dice_roll >= 15:
		result_label.text = ">> 대박! 진귀한 보물과 주사위를 발견했습니다!"
		result_label.modulate = Color.GOLD
		get_node("/root/GameManager")._trigger_dice_reward()
	else:
		result_label.text = ">> 상자 안에서 약간의 소모품을 찾았습니다."
		result_label.modulate = Color.CYAN
	_end_event()

func _play_dice_animation():
	dice_visual_node.visible = true
	dice_visual_node.setup(20, 1, Color("e67e22"))
	# [연출] 구르기 시작 시 숫자 숨김 (회전 애니메이션 강조)
	dice_visual_node.set_rolling(true)
	
	var duration = 1.5 
	var elapsed = 0.0
	var timer = 0.0
	
	while elapsed < duration:
		var delta = get_process_delta_time()
		elapsed += delta
		timer += delta
		
		var current_interval = lerp(0.05, 0.2, elapsed / duration)
		
		if timer >= current_interval:
			timer = 0.0
			var temp_roll = randi_range(1, 20)
			result_label.text = "🎲 [ %d ]" % temp_roll
			
			# [수정] 이제 렉 걱정 없이 구르는 동안에도 숫자를 실시간 매핑합니다!
			if dice_visual_node:
				dice_visual_node.current_value = temp_roll
				dice_visual_node._update_number_texture() # 고속 캐시로 매핑
				dice_visual_node.sync_rolling_frame(randi() % 6)
			
			# [사운드] 눈금 변화 시점 (틱!)
			# sfx_player.stream = load("res://assets/audio/sfx/dice_tick.wav")
			# sfx_player.play()
		
		await get_tree().process_frame

func _set_dice_final_result(val: int):
	# [연출] 정지 시 숫자 다시 표시 및 최종 값 설정
	dice_visual_node.current_value = val
	dice_visual_node.set_rolling(false)
	dice_visual_node._update_number_texture()
	dice_visual_node.sync_frame(6)
	
	# [사운드] 최종 정지 시점 (쿵!)
	# sfx_player.stream = load("res://assets/audio/sfx/dice_impact.wav")
	# sfx_player.play()
	
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

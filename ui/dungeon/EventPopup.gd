extends Panel

signal event_completed

@onready var title_label: Label = $TitleLabel
@onready var desc_label: RichTextLabel = $DescriptionLabel
@onready var btn_force: Button = $Option1Button
@onready var btn_disarm: Button = $Option2Button
@onready var result_label: Label = $ResultLabel

var trap_difficulty: int = 15
var player_agility: int = 0
var agility_bonus: int = 0
var trap_damage: int = 10

func _ready():
	visible = false
	result_label.text = ""
	
	# 스타일링 (임시)
	custom_minimum_size = Vector2(400, 300)
	anchors_preset = Control.PRESET_CENTER
	
	btn_force.pressed.connect(_on_force_pressed)
	btn_disarm.pressed.connect(_on_disarm_pressed)

func setup(difficulty: int, damage: int, player_agi: int):
	trap_difficulty = difficulty
	trap_damage = damage
	player_agility = player_agi
	agility_bonus = int(player_agi / 2) # 보정치: 민첩의 절반
	
	title_label.text = "함정 발견!"
	desc_label.text = "전방에 위험한 장치가 있습니다.\n(난이도 DC: %d)" % trap_difficulty
	
	btn_force.text = "강행 돌파 (HP -%d)" % trap_damage
	btn_disarm.text = "해제 시도 (1d20 + %d)" % agility_bonus
	
	result_label.text = ""
	btn_force.disabled = false
	btn_disarm.disabled = false
	visible = true

func _on_force_pressed():
	_apply_damage(trap_damage)
	result_label.text = "함정을 몸으로 받아냈습니다!"
	_end_event()

func _on_disarm_pressed():
	btn_force.disabled = true
	btn_disarm.disabled = true
	
	var dice_roll = randi_range(1, 20)
	var total = dice_roll + agility_bonus
	
	var result_text = "주사위: %d + 보정: %d = 합계: %d\n" % [dice_roll, agility_bonus, total]
	
	if total >= trap_difficulty:
		result_text += ">> 성공! 함정을 무력화했습니다."
		result_label.modulate = Color.GREEN
		_apply_damage(0) # 피해 없음
	else:
		result_text += ">> 실패! 함정이 작동했습니다."
		result_label.modulate = Color.RED
		# 실패 시 더 큰 피해? 아니면 기본 피해? 일단 기본 피해
		_apply_damage(trap_damage)
	
	result_label.text = result_text
	
	# 잠시 후 종료
	var timer = get_tree().create_timer(2.0)
	await timer.timeout
	_end_event()

func _apply_damage(amount: int):
	if amount > 0:
		var player = get_node("/root/GameManager").player_node
		if player:
			player.take_damage(amount) # 기존 피격 함수 활용

func _end_event():
	visible = false
	emit_signal("event_completed")

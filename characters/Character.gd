class_name Character
extends CharacterBody2D

# 공통 스탯
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var attack_power: int = 10
@export var defense: int = 0
@export var attack_speed: float = 100.0 # 100.0은 기본 속도, 높을수록 빠름
@export var recovery_power: int = 0 # 회복력 스탯 추가

var action_gauge: float = 0.0 # 행동 게이지
var target: CharacterBody2D # 공격 대상 (Player 또는 Enemy)
var ui_manager: Node # UIManager 참조 추가
var is_in_battle: bool = false

@onready var action_gauge_bar = $ProgressBar # 씬 트리에 추가된 ProgressBar 노드를 참조
@onready var hp_label = $Label # 씬 트리에 추가된 Label 노드를 참조

func _ready():
	set_process(false) # 기본적으로 _process 비활성화
	input_pickable = true # 클릭 이벤트를 받을 수 있도록 설정
	action_gauge = 0.0 # 게이지 초기화
	update_hp_label() # 초기 HP 표시

	# UI 요소 위치 설정 (스크립트에서 제어)
	action_gauge_bar.position = Vector2(-32, -45) # ProgressBar 위치
	hp_label.position = Vector2(-32, 20) # Label 위치

func _process(delta: float):
	if current_hp <= 0: # 사망 시 행동 중지
		action_gauge_bar.value = 0 # 사망 시 게이지 0으로
		action_gauge = 0.0 # 게이지 초기화
		return
	if target == null or target.current_hp <= 0: # 대상이 없거나 사망 시 행동 중지
		action_gauge_bar.value = 0 # 대상 없을 시 게이지 0으로
		action_gauge = 0.0 # 게이지 초기화
		return

	action_gauge += attack_speed * delta # 공격 속도에 비례하여 게이지 증가
	action_gauge_bar.value = action_gauge # ProgressBar 업데이트

	if action_gauge >= 100.0: # 게이지가 가득 차면 공격
		action_gauge = 0.0 # 게이지 초기화
		attack(target) # 대상에게 공격

func _input(_event: InputEvent):
	pass # 마우스 이벤트 디버그 로그 제거

func take_damage(amount: int):
	var final_damage = max(0, amount - defense) # 방어력만큼 데미지 감소 (최소 0)
	current_hp -= final_damage
	
	update_hp_label() # HP 변경 시 라벨 업데이트
	print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", current_hp)
	if current_hp <= 0:
		print(name, " 사망!")
		set_process(false) # 사망 시 _process 중지

func update_hp_label():
	hp_label.text = "HP: " + str(current_hp) + "/" + str(max_hp)

func attack(target_node: CharacterBody2D):
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", attack_power)
	target_node.take_damage(attack_power)

func reset_for_next_battle():
	action_gauge = 0.0
	if action_gauge_bar:
		action_gauge_bar.value = 0.0
	print(name, "의 행동 게이지가 초기화되었습니다.")

func apply_dice_to_stat(stat_name: String, value: int):
	match stat_name:
		"attack_power":
			attack_power += value
			print("공격력에 ", value, " 추가. 현재 공격력: ", attack_power)
		"max_hp":
			max_hp += value
			current_hp += value # 최대 체력 증가 시 현재 체력도 증가
			print("최대 체력에 ", value, " 추가. 현재 최대 체력: ", max_hp)
		"defense":
			defense += value
			print("방어력에 ", value, " 추가. 현재 방어력: ", defense)
		"attack_speed":
			attack_speed += value
			print("공격 속도에 ", value, " 추가. 현재 공격 속도: ", attack_speed)
		"recovery_power":
			recovery_power += value
			print("회복력에 ", value, " 추가. 현재 회복력: ", recovery_power)
		_:
			print("알 수 없는 스탯: ", stat_name)

	# UI 업데이트
	if ui_manager:
		ui_manager.update_player_stats_ui(self)

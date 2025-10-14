class_name Character
extends CharacterBody2D



var action_gauge: float = 0.0 # 행동 게이지
var target: CharacterBody2D # 공격 대상 (Player 또는 Enemy)
var ui_manager: Node # UIManager 참조 추가
var is_in_battle: bool = false

# Stat Getters/Setters (to be overridden by Player and EnemyCharacter)
func get_max_hp() -> int: return 0
func set_max_hp(value: int): pass
func get_current_hp() -> int: return 0
func set_current_hp(value: int): pass
func get_attack_power() -> int: return 0
func set_attack_power(value: int): pass
func get_defense() -> int: return 0
func set_defense(value: int): pass
func get_attack_speed() -> float: return 0.0
func set_attack_speed(value: float): pass
func get_recovery_power() -> int: return 0
func set_recovery_power(value: int): pass
func get_max_mp() -> int: return 0
func set_max_mp(value: int): pass
func get_current_mp() -> int: return 0
func set_current_mp(value: int): pass
func get_luck() -> int: return 0
func set_luck(value: int): pass
func get_resistance() -> int: return 0
func set_resistance(value: int): pass

@onready var action_gauge_bar = $ProgressBar # 씬 트리에 추가된 ProgressBar 노드를 참조
@onready var hp_label = $Label # 씬 트리에 추가된 Label 노드를 참조

func _ready():
	set_process(false) # 기본적으로 _process 비활성화
	input_pickable = true # 클릭 이벤트를 받을 수 있도록 설정
	action_gauge = 0.0 # 게이지 초기화
	set_current_mp(get_max_mp()) # 현재 MP 초기화
	update_hp_label() # 초기 HP 표시

	# input_event 시그널 연결
	connect("input_event", Callable(self, "_on_input_event"))

	# UI 요소 위치 설정 (스크립트에서 제어)
	action_gauge_bar.position = Vector2(-32, -45) # ProgressBar 위치
	hp_label.position = Vector2(-32, 20) # Label 위치

func _process(delta: float):
	if get_current_hp() <= 0: # 사망 시 행동 중지
		action_gauge_bar.value = 0 # 사망 시 게이지 0으로
		action_gauge = 0.0 # 게이지 초기화
		return
	if target == null or target.get_current_hp() <= 0: # 대상이 없거나 사망 시 행동 중지
		action_gauge_bar.value = 0 # 대상 없을 시 게이지 0으로
		action_gauge = 0.0 # 게이지 초기화
		return

	action_gauge += get_attack_speed() * delta # 공격 속도에 비례하여 게이지 증가
	action_gauge_bar.value = action_gauge # ProgressBar 업데이트

	if action_gauge >= 100.0: # 게이지가 가득 차면 공격
		action_gauge = 0.0 # 게이지 초기화
		attack(target) # 대상에게 공격


	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if ui_manager and ui_manager.has_method("show_status_popup"):
			ui_manager.show_status_popup(self)

func take_damage(amount: int):
	var final_damage = max(0, amount - get_defense()) # 방어력만큼 데미지 감소 (최소 0)
	set_current_hp(get_current_hp() - final_damage)
	
	update_hp_label() # HP 변경 시 라벨 업데이트
	print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", current_hp)
	if get_current_hp() <= 0:
		print(name, " 사망!")
		set_process(false) # 사망 시 _process 중지

func update_hp_label():
	hp_label.text = "HP: " + str(get_current_hp()) + "/" + str(get_max_hp())

func attack(target_node: CharacterBody2D):
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", get_attack_power())
	target_node.take_damage(attack_power)

func reset_for_next_battle():
	action_gauge = 0.0
	if action_gauge_bar:
		action_gauge_bar.value = 0.0
	print(name, "의 행동 게이지가 초기화되었습니다.")

func apply_dice_to_stat(stat_name: String, value: int):
	match stat_name:
		"attack_power":
			set_attack_power(get_attack_power() + value)
			print("공격력에 ", value, " 추가. 현재 공격력: ", get_attack_power())
		"max_hp":
			set_max_hp(get_max_hp() + value)
			set_current_hp(get_current_hp() + value) # 최대 체력 증가 시 현재 체력도 증가
			print("최대 체력에 ", value, " 추가. 현재 최대 체력: ", get_max_hp())
		"defense":
			set_defense(get_defense() + value)
			print("방어력에 ", value, " 추가. 현재 방어력: ", get_defense())
		"attack_speed":
			set_attack_speed(get_attack_speed() + value)
			print("공격 속도에 ", value, " 추가. 현재 공격 속도: ", get_attack_speed())
		"recovery_power":
			set_recovery_power(get_recovery_power() + value)
			print("회복력에 ", value, " 추가. 현재 회복력: ", get_recovery_power())
		"max_mp":
			set_max_mp(get_max_mp() + value)
			set_current_mp(get_current_mp() + value) # 최대 마력 증가 시 현재 마력도 증가
			print("최대 마력에 ", value, " 추가. 현재 최대 마력: ", get_max_mp())
		"luck":
			set_luck(get_luck() + value)
			print("행운에 ", value, " 추가. 현재 행운: ", get_luck())
		"resistance":
			set_resistance(get_resistance() + value)
			print("저항에 ", value, " 추가. 현재 저항: ", get_resistance())
		_:
			print("알 수 없는 스탯: ", stat_name)

	# UI 업데이트
	if ui_manager:
		ui_manager.update_player_stats_ui(self)

class_name Character
extends CharacterBody2D

# Core Stats
var max_hp: int = 1
var current_hp: int = 1
var max_mp: int = 0
var current_mp: int = 0
var attack_power: int = 1
var defense: int = 0
var attack_speed: float = 1.0
var recovery_power: int = 0
var luck: int = 0
var resistance: int = 0

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false

# --- Stat Getters/Setters ---
func get_max_hp() -> int: return max_hp
func set_max_hp(value: int): max_hp = value

func get_current_hp() -> int: return current_hp
func set_current_hp(value: int): current_hp = max(0, value)

func get_attack_power() -> int: return attack_power
func set_attack_power(value: int): attack_power = value

func get_defense() -> int: return defense
func set_defense(value: int): defense = value

func get_attack_speed() -> float: return attack_speed
func set_attack_speed(value: float): attack_speed = value

func get_recovery_power() -> int: return recovery_power
func set_recovery_power(value: int): recovery_power = value

func get_max_mp() -> int: return max_mp
func set_max_mp(value: int): max_mp = value

func get_current_mp() -> int: return current_mp
func set_current_mp(value: int): current_mp = max(0, value)

func get_luck() -> int: return luck
func set_luck(value: int): luck = value

func get_resistance() -> int: return resistance
func set_resistance(value: int): resistance = value
# --- End of Stat Getters/Setters ---

@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label

func _ready():
	set_process(false)
	input_pickable = true
	action_gauge = 0.0
	current_mp = get_max_mp()
	update_hp_label()
	connect("input_event", Callable(self, "_on_input_event"))
	action_gauge_bar.position = Vector2(-32, -45)
	hp_label.position = Vector2(-32, 20)

func _process(delta: float):
	if current_hp <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	if target == null or not is_instance_valid(target) or target.get_current_hp() <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return

	action_gauge += attack_speed * delta
	action_gauge_bar.value = action_gauge

	if action_gauge >= 100.0:
		action_gauge = 0.0
		attack(target)

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	var final_damage = max(0, amount - defense)
	current_hp -= final_damage
	
	update_hp_label()
	print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", current_hp)
	if current_hp <= 0:
		print(name, " 사망!")
		set_process(false)

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
			current_hp += value
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
		"max_mp":
			max_mp += value
			current_mp += value
			print("최대 마력에 ", value, " 추가. 현재 최대 마력: ", max_mp)
		"luck":
			luck += value
			print("행운에 ", value, " 추가. 현재 행운: ", luck)
		"resistance":
			resistance += value
			print("저항에 ", value, " 추가. 현재 저항: ", resistance)
		_:
			print("알 수 없는 스탯: ", stat_name)

	if ui_manager:
		ui_manager.update_player_stats_ui(self)

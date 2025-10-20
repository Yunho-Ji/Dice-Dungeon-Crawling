class_name Character
extends CharacterBody2D

signal damage_taken(amount: int, position: Vector2)

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false

@onready var stats_manager: MyStatsManager = $MyStatsManager # Reference to the new stat manager


@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label

func _ready():
	print("DEBUG: Character.gd: _ready called for ", name) # New line
	set_process(false)
	input_pickable = true
	action_gauge = 0.0
	# Stat initialization will be handled by GameManager calling set_stats()
	# update_hp_label() will be called by set_stats()
	connect("input_event", Callable(self, "_on_input_event"))
	action_gauge_bar.position = Vector2(-32, -45)
	hp_label.position = Vector2(-32, 20)

func _process(delta: float):
	if stats_manager.get_stat("health").computed_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	if target == null or not is_instance_valid(target) or target.stats_manager.get_stat("health").computed_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return

	action_gauge += stats_manager.get_stat("attack_speed").computed_value * delta
	action_gauge_bar.value = action_gauge

	if action_gauge >= 100.0:
		action_gauge = 0.0
		attack(target)

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	var final_damage = max(0, amount - stats_manager.get_stat("defense").computed_value)
	stats_manager.get_stat("health").base_value -= final_damage # Direct modification of base_value
	stats_manager.get_stat("health").base_value = max(0, stats_manager.get_stat("health").computed_value) # Ensure HP doesn't go below 0

	update_hp_label()
	emit_signal("damage_taken", final_damage, global_position) # Emit signal
	print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", stats_manager.get_stat("health").computed_value)
	if stats_manager.get_stat("health").computed_value <= 0:
		print(name, " 사망!")
		set_process(false)

func update_hp_label():
	hp_label.text = "HP: " + str(stats_manager.get_stat("health").computed_value) + "/" + str(stats_manager.get_stat("health").base_value)

func attack(target_node: CharacterBody2D):
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", stats_manager.get_stat("attack_power").computed_value)
	target_node.take_damage(stats_manager.get_stat("attack_power").computed_value)

func reset_for_next_battle():
	action_gauge = 0.0
	if action_gauge_bar:
		action_gauge_bar.value = 0.0
	print(name, "의 행동 게이지가 초기화되었습니다.")

func apply_dice_to_stat(stat_name: String, value: int):
	var stat = stats_manager.get_stat(stat_name)
	if stat:
		stat.base_value += value # Direct modification of base_value
		print(stat_name, "에 ", value, " 추가. 현재 값: ", stat.computed_value)
	else:
		print("알 수 없는 스탯: ", stat_name)

	if ui_manager and ui_manager.has_method("update_player_stats_ui"):
		ui_manager.update_player_stats_ui(stats_manager) # Pass stats_manager

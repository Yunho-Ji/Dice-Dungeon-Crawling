class_name Character
extends CharacterBody2D

signal damage_taken(amount: int, position: Vector2)

# Core Stats
var stats: Dictionary = {
	"max_hp": 1,
	"current_hp": 1,
	"max_mp": 0,
	"current_mp": 0,
	"attack_power": 1,
	"defense": 0,
	"attack_speed": 1.0,
	"recovery_power": 0,
	"luck": 0,
	"resistance": 0
}

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false

# --- Stat Getters/Setters ---
func get_stat(stat_name: String):
	if stats.has(stat_name):
		return stats[stat_name]
	printerr("Request for unknown stat: ", stat_name)
	return null

func set_stat(stat_name: String, value):
	if stats.has(stat_name):
		stats[stat_name] = value
		if stat_name == "max_hp": # Ensure current_hp doesn't exceed max_hp
			stats["current_hp"] = min(stats["current_hp"], stats["max_hp"])
		elif stat_name == "max_mp":
			stats["current_mp"] = min(stats["current_mp"], stats["max_mp"])
	else:
		printerr("Attempt to set unknown stat: ", stat_name)

func apply_stat(stat_name: String, value):
	if stats.has(stat_name):
		stats[stat_name] += value
		# Special handling for HP/MP when max is increased
		if stat_name == "max_hp" and value > 0:
			stats["current_hp"] += value
		elif stat_name == "max_mp" and value > 0:
			stats["current_mp"] += value
	else:
		printerr("Attempt to apply to unknown stat: ", stat_name)

# --- End of Stat Getters/Setters ---

@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label

func _ready():
	print("DEBUG: Character.gd: _ready called for ", name) # New line
	set_process(false)
	input_pickable = true
	action_gauge = 0.0
	set_stat("current_mp", get_stat("max_mp"))
	update_hp_label()
	connect("input_event", Callable(self, "_on_input_event"))
	action_gauge_bar.position = Vector2(-32, -45)
	hp_label.position = Vector2(-32, 20)

func _process(delta: float):
	if get_stat("current_hp") <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	if target == null or not is_instance_valid(target) or target.get_stat("current_hp") <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return

	action_gauge += get_stat("attack_speed") * delta
	action_gauge_bar.value = action_gauge

	if action_gauge >= 100.0:
		action_gauge = 0.0
		attack(target)

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	var final_damage = max(0, amount - get_stat("defense"))
	apply_stat("current_hp", -final_damage)
	set_stat("current_hp", max(0, get_stat("current_hp"))) # Ensure HP doesn't go below 0

	update_hp_label()
	emit_signal("damage_taken", final_damage, global_position) # Emit signal
	print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", get_stat("current_hp"))
	if get_stat("current_hp") <= 0:
		print(name, " 사망!")
		set_process(false)

func update_hp_label():
	hp_label.text = "HP: " + str(get_stat("current_hp")) + "/" + str(get_stat("max_hp"))

func attack(target_node: CharacterBody2D):
	print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", get_stat("attack_power"))
	target_node.take_damage(get_stat("attack_power"))

func reset_for_next_battle():
	action_gauge = 0.0
	if action_gauge_bar:
		action_gauge_bar.value = 0.0
	print(name, "의 행동 게이지가 초기화되었습니다.")

func apply_dice_to_stat(stat_name: String, value: int):
	if stats.has(stat_name):
		apply_stat(stat_name, value)
		print(stat_name, "에 ", value, " 추가. 현재 값: ", get_stat(stat_name))
	else:
		print("알 수 없는 스탯: ", stat_name)

	if ui_manager and ui_manager.has_method("update_player_stats_ui"):
		ui_manager.update_player_stats_ui(self)

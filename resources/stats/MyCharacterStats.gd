extends Resource
class_name MyCharacterStats

@export var health: MyIntStat = MyIntStat.new()
@export var attack_power: MyIntStat = MyIntStat.new()
@export var defense: MyIntStat = MyIntStat.new()
@export var attack_speed: MyIntStat = MyIntStat.new()
@export var current_mp: MyIntStat = MyIntStat.new() # Assuming MP is also an IntStat
@export var recovery_power: MyIntStat = MyIntStat.new() # Added recovery_power
@export var luck: MyIntStat = MyIntStat.new() # Added luck
@export var resistance: MyIntStat = MyIntStat.new() # Added resistance

func _init():
	health.key = "health"
	attack_power.key = "attack_power"
	defense.key = "defense"
	attack_speed.key = "attack_speed"
	current_mp.key = "current_mp"
	recovery_power.key = "recovery_power" # Added key for recovery_power
	luck.key = "luck" # Added key for luck
	resistance.key = "resistance" # Added key for resistance

func get_stat(key: String) -> MyStat:
	match key:
		"health": return health
		"attack_power": return attack_power
		"defense": return defense
		"attack_speed": return attack_speed
		"current_mp": return current_mp
		"recovery_power": return recovery_power
		"luck": return luck # Added luck
		"resistance": return resistance # Added resistance
	return null

func get_all_stats() -> Array[MyStat]:
	return [health, attack_power, defense, attack_speed, current_mp, recovery_power, luck, resistance] # Added luck and resistance # Added recovery_power
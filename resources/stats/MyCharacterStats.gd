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

func get_all_stat_keys() -> Array[String]:
	return ["health", "attack_power", "defense", "attack_speed", "current_mp", "recovery_power", "luck", "resistance"]

# Ensures a true deep copy of this resource is created.
func _duplicate(deep: bool = false) -> Resource:
	var new_instance = MyCharacterStats.new()

	# Manually copy/duplicate the stat properties
	if deep:
		new_instance.health = health.clone()
		new_instance.attack_power = attack_power.clone()
		new_instance.defense = defense.clone()
		new_instance.attack_speed = attack_speed.clone()
		new_instance.current_mp = current_mp.clone()
		new_instance.recovery_power = recovery_power.clone()
		new_instance.luck = luck.clone()
		new_instance.resistance = resistance.clone()
	else:
		# For a shallow copy, just assign the references
		new_instance.health = health
		new_instance.attack_power = attack_power
		new_instance.defense = defense
		new_instance.attack_speed = attack_speed
		new_instance.current_mp = current_mp
		new_instance.recovery_power = recovery_power
		new_instance.luck = luck
		new_instance.resistance = resistance
	
	return new_instance

func sync_from(source_stats: MyCharacterStats):
	if not source_stats:
		printerr("ERROR: MyCharacterStats: Source stats for sync_from is null.")
		return
	
	for stat_key in get_all_stat_keys():
		var source_stat = source_stats.get_stat(stat_key)
		var target_stat = get_stat(stat_key)
		
		if source_stat and target_stat:
			target_stat.sync_from(source_stat)
		else:
			printerr("ERROR: MyCharacterStats: Failed to sync stat '", stat_key, "'. Source or target stat is null.")

func apply_dice_to_stat(stat_name: String, value: int):
	var stat = get_stat(stat_name)
	if stat:
		stat.base_value += value # Direct modification of base_value
		stat.current_value += value # Also update current_value
		print(stat_name, "에 ", value, " 추가. 현재 값: ", stat.computed_value)
	else:
		print("알 수 없는 스탯: ", stat_name)

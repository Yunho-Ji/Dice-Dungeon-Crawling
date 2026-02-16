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
@export var intelligence: MyIntStat = MyIntStat.new() # 지능 (MP 재생, 마법 데미지)
@export var agility: MyIntStat = MyIntStat.new() # 민첩 (회피 리스크 완화, 빗겨맞음)
@export var shield: MyIntStat = MyIntStat.new() # 보호막 (기능적 스탯)
@export var motion_speed: MyStat = MyStat.new() # 모션 속도 (기능적 스탯, 기본값 1.0)
@export var piercing: MyStat = MyStat.new() # 방어 관통력 (0.0 ~ 1.0)
@export var true_damage: MyStat = MyStat.new() # 트루 데미지 비율 (0.0 ~ 1.0, 보호막/방어 무시)

func _init():
	health.key = "health"
	attack_power.key = "attack_power"
	defense.key = "defense"
	attack_speed.key = "attack_speed"
	current_mp.key = "current_mp"
	recovery_power.key = "recovery_power" # Added key for recovery_power
	luck.key = "luck" # Added key for luck
	resistance.key = "resistance" # Added key for resistance
	intelligence.key = "intelligence"
	agility.key = "agility"
	shield.key = "shield"
	motion_speed.key = "motion_speed"
	motion_speed.base_value = 1.0 # 기본 속도 100%
	piercing.key = "piercing"
	piercing.base_value = 0.0 # 기본 방어 관통 0%
	true_damage.key = "true_damage"
	true_damage.base_value = 0.0 # 기본 트루 데미지 0%

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
		"intelligence": return intelligence
		"agility": return agility
		"shield": return shield
		"motion_speed": return motion_speed
		"piercing": return piercing
		"true_damage": return true_damage
	return null

func get_all_stats() -> Array[MyStat]:
	return [health, attack_power, defense, attack_speed, current_mp, recovery_power, luck, resistance, intelligence, agility, shield, motion_speed, piercing, true_damage]

func get_all_stat_keys() -> Array[String]:
	return ["health", "attack_power", "defense", "attack_speed", "current_mp", "recovery_power", "luck", "resistance", "intelligence", "agility", "shield", "motion_speed", "piercing", "true_damage"]

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
		new_instance.intelligence = intelligence.clone()
		new_instance.agility = agility.clone()
		new_instance.shield = shield.clone()
		new_instance.motion_speed = motion_speed.clone()
		new_instance.piercing = piercing.clone()
		new_instance.true_damage = true_damage.clone()
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
		new_instance.intelligence = intelligence
		new_instance.agility = agility
		new_instance.shield = shield
		new_instance.motion_speed = motion_speed
		new_instance.piercing = piercing
		new_instance.true_damage = true_damage
	
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

# [신규] 모든 스탯의 주사위 보너스(Modifiers) 제거
# 운명 설계 단계에서 재분배를 위해 기존 강화 수치를 초기화할 때 사용
func remove_all_modifiers():
	var all_stats = get_all_stats()
	for stat in all_stats:
		if stat and stat.has_method("clear_modifiers"):
			# MyStat에 정의된 공식 메서드를 통해 수정자 제거 및 신호 발생
			stat.clear_modifiers()
			# 현재 값(current_value)도 베이스 수치로 동기화
			stat.current_value = stat.base_value

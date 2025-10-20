extends Stats
class_name PlayerStatsResource

@export var health: IntStat = IntStat.new()
@export var attack: IntStat = IntStat.new()

func _init():
	health.key = "Health"
	attack.key = "Attack"
extends Node
class_name MyStatsManager

@export var character_stats: MyCharacterStats

func get_stat(key: String) -> MyStat:
	if character_stats:
		return character_stats.get_stat(key)
	return null

func add_modifier(stat_key: String, modifier: MyStatModifier):
	var stat = get_stat(stat_key)
	if stat:
		stat.add_modifier(modifier)

func remove_modifier(stat_key: String, modifier: MyStatModifier):
	var stat = get_stat(stat_key)
	if stat:
		stat.remove_modifier(modifier)

func clear_modifiers(stat_key: String):
	var stat = get_stat(stat_key)
	if stat:
		stat.clear_modifiers()

func get_all_stats() -> Array[MyStat]:
	if character_stats:
		return character_stats.get_all_stats()
	return []

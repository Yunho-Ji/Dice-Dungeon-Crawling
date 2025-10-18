extends Node

const CLASS_STATS = {
	"novice": {
		"max_hp": 130, "attack_power": 10, "defense": 5, "attack_speed": 100.0
	},
	"archer": {
		"max_hp": 80, "attack_power": 16, "defense": 3, "attack_speed": 120.0
	}
}

var selected_player_type: String = "novice"

func get_class_stats(player_class: String) -> Dictionary:
	if CLASS_STATS.has(player_class):
		return CLASS_STATS[player_class]
	printerr("PlayerManager: Unknown player class: ", player_class)
	return {}

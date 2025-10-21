extends Node

const CLASS_BASE_STATS = {
	"novice": {
		"health": 130, "attack_power": 10, "defense": 5, "attack_speed": 100, "current_mp": 0, "recovery_power": 0, "luck": 0, "resistance": 0
	},
	"archer": {
		"health": 80, "attack_power": 16, "defense": 3, "attack_speed": 120, "current_mp": 0, "recovery_power": 0, "luck": 0, "resistance": 0
	}
}

var selected_player_type: String = "novice"
var current_player_stats: MyCharacterStats # 현재 플레이어의 성장된 스탯을 저장

func _ready():
	# 게임 시작 시 기본 스탯으로 초기화 (또는 로드된 데이터로)
	if current_player_stats == null: # Check if MyCharacterStats is null
		initialize_player_stats(selected_player_type)

func initialize_player_stats(player_class: String):
	current_player_stats = MyCharacterStats.new() # Create a new instance
	if CLASS_BASE_STATS.has(player_class):
		var base_stats_dict = CLASS_BASE_STATS[player_class]
		current_player_stats.health.base_value = base_stats_dict["health"]
		current_player_stats.attack_power.base_value = base_stats_dict["attack_power"]
		current_player_stats.defense.base_value = base_stats_dict["defense"]
		current_player_stats.attack_speed.base_value = base_stats_dict["attack_speed"]
		current_player_stats.current_mp.base_value = base_stats_dict["current_mp"]
		print("PlayerManager: Player stats initialized for ", player_class, ": ", current_player_stats)
	else:
		printerr("PlayerManager: Unknown player class for initialization: ", player_class)

func get_class_stats(player_class: String) -> MyCharacterStats:
	var character_stats_instance = MyCharacterStats.new()
	if CLASS_BASE_STATS.has(player_class):
		var base_stats_dict = CLASS_BASE_STATS[player_class]
		character_stats_instance.health.base_value = base_stats_dict["health"]
		character_stats_instance.attack_power.base_value = base_stats_dict["attack_power"]
		character_stats_instance.defense.base_value = base_stats_dict["defense"]
		character_stats_instance.attack_speed.base_value = base_stats_dict["attack_speed"]
		character_stats_instance.current_mp.base_value = base_stats_dict["current_mp"]
		return character_stats_instance
	printerr("PlayerManager: Unknown player class: ", player_class)
	return null

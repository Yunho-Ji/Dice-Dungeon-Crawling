extends Node

@export var player_data: CharacterData # 플레이어의 캐릭터 데이터 리소스
var current_player_stats: MyCharacterStats # 전투 간 플레이어의 현재 스탯을 저장


func _print_stats_debug_info(context: String):
	print("DEBUG: PlayerManager: --- Stats Debug Info (Context: ", context, ") ---")
	if player_data and player_data.base_stats:
		print("DEBUG: PlayerManager: player_data.base_stats instance ID: ", player_data.base_stats.get_instance_id())
		for stat_key in player_data.base_stats.get_all_stat_keys():
			var stat = player_data.base_stats.get_stat(stat_key)
			if stat:
				print("DEBUG: PlayerManager:   player_data.base_stats - ", stat.key, ": computed=", stat.computed_value, ", modifiers=", stat.modifiers.size())
	else:
		print("DEBUG: PlayerManager: player_data.base_stats is null or invalid.")
	
	if current_player_stats:
		print("DEBUG: PlayerManager: current_player_stats instance ID: ", current_player_stats.get_instance_id())
		for stat_key in current_player_stats.get_all_stat_keys():
			var stat = current_player_stats.get_stat(stat_key)
			if stat:
				print("DEBUG: PlayerManager:   current_player_stats - ", stat.key, ": computed=", stat.computed_value, ", modifiers=", stat.modifiers.size())
				for modifier in stat.modifiers:
					print("DEBUG: PlayerManager:     Modifier: ", modifier.value, " (", modifier.operation, ")")
	else:
		print("DEBUG: PlayerManager: current_player_stats is null or invalid.")
	print("DEBUG: PlayerManager: ------------------------------------------")

func _ready():
	if player_data == null:
		player_data = (load("res://resources/characters/player/Novice.tres") as CharacterData).duplicate(true)
	
	
	_print_stats_debug_info("_ready")

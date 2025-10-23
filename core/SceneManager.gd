extends Node

signal game_started

@export var town_scene_path: String = "res://ui/Town.tscn"
@export var map_scene_path: String = "res://ui/Map.tscn"
@export var main_scene_path: String = "res://levels/Main.tscn"



func start_game_with_character(character_data: CharacterData):
	var player_manager = get_node("/root/PlayerManager")
	if player_manager:
		player_manager.player_data = character_data
		# 임시: 만약 player_data가 여전히 null이면 Novice.tres를 로드 (테스트용)
		if player_manager.player_data == null:
			player_manager.player_data = load("res://resources/characters/player/Novice.tres")
	go_to_town()
	emit_signal("game_started")

func go_to_town(from_dungeon_return: bool = false):
	if from_dungeon_return:
		get_node("/root/TownManager").set_time_by_minutes(get_node("/root/TownManager").RETURN_TIME_MINUTES)
	get_tree().change_scene_to_file(town_scene_path)

func go_to_map():
	get_tree().change_scene_to_file(map_scene_path)

func start_dungeon(dungeon_id: int, is_additional_exploration: bool = false):
	var game_manager = get_node("/root/GameManager")
	game_manager.selected_dungeon_id = dungeon_id
	game_manager.is_additional_exploration_mode = is_additional_exploration # Set the flag
	game_manager.current_stage = dungeon_id
	game_manager.current_battle_count = 0
	get_tree().change_scene_to_file(main_scene_path)

func reload_current_scene():
	get_tree().reload_current_scene()

func go_to_main_menu():
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

# SceneManager.gd
extends Node

signal game_started

@export var town_scene_path: String = "res://ui/Town.tscn"
@export var map_scene_path: String = "res://ui/Map.tscn"
@export var main_scene_path: String = "res://levels/Main.tscn"



func start_game_with_character(character_data: Resource):
	var player_manager = get_node_or_null("/root/PlayerManager")
	if player_manager:
		player_manager.set("player_data", character_data)
		if character_data and character_data.get("base_stats"):
			player_manager.set("current_player_stats", character_data.get("base_stats").duplicate(true))
			print("DEBUG: SceneManager: Player session stats initialized.")
		
		if player_manager.has_method("initialize_session"):
			player_manager.initialize_session()
		
	go_to_town()
	emit_signal("game_started")

func go_to_town(from_dungeon_return: bool = false):
	var tm = get_node_or_null("/root/TownManager")
	if from_dungeon_return and tm:
		tm.call("set_time_by_minutes", tm.get("RETURN_TIME_MINUTES"))
	get_tree().change_scene_to_file(town_scene_path)

func go_to_map():
	get_tree().change_scene_to_file(map_scene_path)

func start_dungeon(dungeon_id: int, is_additional_exploration: bool = false):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("selected_dungeon_id", dungeon_id)
		gm.set("is_additional_exploration_mode", is_additional_exploration)
		gm.set("current_stage", dungeon_id)
		gm.set("current_battle_count", 0)
	get_tree().change_scene_to_file(main_scene_path)

func reload_current_scene():
	get_tree().reload_current_scene()

func go_to_main_menu():
	get_tree().change_scene_to_file("res://ui/MainMenu.tscn")

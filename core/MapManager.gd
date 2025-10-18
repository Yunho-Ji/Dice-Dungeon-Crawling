extends Node

# Dungeon State
var dungeon_data: Dictionary = {}
var dungeon_max_depth: int = 0
var should_generate_new_dungeon: bool = true

# Player's progress within the current dungeon
var player_run_state: Dictionary = {
	"PermanentViewLevel": 0,
	"CurrentNodeID": "",
	"VisitedNodeIDs": [],
	"KnownNodeData": {},
	"SelectedBossRoute": "",
	# Add other run-specific resources here later
}

# Scene References
@export var dungeon_map_scene: PackedScene

# Manager/Node References (set in _ready)
var game_manager: Node
var ui_manager: Node
var battle_manager: Node
var player_node: Node
var enemy_node: Node
var stage_info_hud: Node

func _ready():
	# Load scenes and get manager references
	dungeon_map_scene = load("res://ui/dungeon/DungeonMap.tscn")
	game_manager = get_node("/root/GameManager")
	# Other managers will be fetched when needed, as they live on the Main scene

func generate_dungeon_if_needed():
	if should_generate_new_dungeon:
		print("DEBUG: MapManager: Generating new dungeon.")
		
		var dungeon_config = game_manager.DUNGEON_CONFIGS[game_manager.selected_dungeon_id]
		
		var dungeon_generator = DungeonGenerator.new()
		dungeon_data = dungeon_generator.generate_dungeon(dungeon_config)
		dungeon_max_depth = dungeon_generator.num_layers # This will be set by generator based on config
		player_run_state.CurrentNodeID = "start_0"
		player_run_state.VisitedNodeIDs.clear()
		should_generate_new_dungeon = false
		# Grant a dice roll for starting a new dungeon (Rule #1)
		get_node("/root/DiceManager").enable_roll()

func show_dungeon_map():
	print("DEBUG: MapManager: show_dungeon_map called.")

	# Ensure we have references to nodes on the main scene
	_get_main_scene_nodes()

	# Hide game world elements
	if is_instance_valid(player_node): player_node.visible = false
	if is_instance_valid(enemy_node): enemy_node.visible = false
	if is_instance_valid(stage_info_hud): stage_info_hud.visible = false

	if not is_instance_valid(ui_manager):
		printerr("MapManager: UIManager is not valid!")
		return

	var dungeon_map_instance = dungeon_map_scene.instantiate()
	dungeon_map_instance.dungeon_map_data = dungeon_data
	dungeon_map_instance.current_node_id = player_run_state.CurrentNodeID
	dungeon_map_instance.player_run_state = player_run_state
	dungeon_map_instance.node_activated.connect(_on_dungeon_node_activated)

	ui_manager.show_screen(UIManager.Screen.DUNGEON_MAP, dungeon_map_instance)
	print("DEBUG: MapManager: UIManager requested to show DungeonMap.")

	update_dungeon_progress_hud()

func _on_dungeon_node_activated(node_id: String):
	print("DEBUG: MapManager: Node activated: ", node_id)
	
	# Update game state
	player_run_state.CurrentNodeID = node_id
	player_run_state.VisitedNodeIDs.append(node_id)
	
	update_dungeon_progress_hud()

	# Tell UIManager to switch back to the battle screen
	ui_manager.show_screen(UIManager.Screen.BATTLE_HUD)
	
	# Tell GameManager to prepare the battle
	if dungeon_data.has(node_id):
		var selected_node: DungeonNode = dungeon_data[node_id]

		# Grant dice roll if the node is a special type (Rule #2)
		if selected_node.node_type == "rest" or selected_node.node_type == "shop":
			get_node("/root/DiceManager").enable_roll()
			print("특수 노드 도착! 주사위 굴림 기회가 부여됩니다.")

		game_manager.prepare_dungeon_battle(selected_node)
	else:
		printerr("ERROR: Node ID '" + node_id + "' not found in dungeon data!")
		game_manager.prepare_dungeon_battle(null) # Fallback

func update_dungeon_progress_hud():
	if not is_instance_valid(stage_info_hud):
		return

	var current_node_id = player_run_state.CurrentNodeID
	if not dungeon_data.has(current_node_id):
		return

	var current_node: DungeonNode = dungeon_data[current_node_id]
	stage_info_hud.update_progress(current_node.depth, dungeon_max_depth)

func set_should_generate_new_dungeon(value: bool):
	should_generate_new_dungeon = value

func _get_main_scene_nodes():
	# This is a helper to safely get nodes that only exist on the main game scene
	if not is_instance_valid(ui_manager):
		ui_manager = game_manager.ui_manager
	if not is_instance_valid(battle_manager):
		battle_manager = game_manager.battle_manager
	if not is_instance_valid(player_node):
		player_node = game_manager.player_node
	if not is_instance_valid(enemy_node):
		enemy_node = game_manager.enemy_node
	if not is_instance_valid(stage_info_hud):
		stage_info_hud = game_manager.stage_info_hud

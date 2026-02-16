extends Node

# Dungeon State
var dungeon_data: Dictionary = {}
var dungeon_max_depth: int = 0
var should_generate_new_dungeon: bool = true
var dungeon_seed: int = 0 # 현재 던전의 Seed를 저장 (int로 변경)

# Player's progress within the current dungeon
var player_run_state: Dictionary = {
	"PermanentViewLevel": 0,
	"CurrentNodeID": "",
	"VisitedNodeIDs": [],
	"KnownNodeData": {},
	"SelectedBossRoute": "",
	"CurrentDepth": 0,
	"vision_range": 1, # For Fog of War system
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

		if dungeon_seed == 0: # 0을 초기값으로 간주
			randomize()
			dungeon_seed = randi()

		var dungeon_config = game_manager.DUNGEON_CONFIGS[game_manager.selected_dungeon_id]

		var dungeon_generator = DungeonGenerator.new()
		dungeon_data = dungeon_generator.generate_dungeon(dungeon_config, dungeon_seed)
		dungeon_max_depth = dungeon_data.num_layers # Get num_layers from the returned dictionary

		# --- Player now chooses a start node from the map ---
		# Find all start nodes
		var start_nodes = []
		for node in dungeon_data.nodes.values():
			if node.node_type == "start":
				start_nodes.append(node)
		
		# Randomly assign a starting node. This is NOT seeded.
		if not start_nodes.is_empty():
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			player_run_state.CurrentNodeID = start_nodes[rng.randi_range(0, start_nodes.size() - 1)].node_id
		else:
			player_run_state.CurrentNodeID = "" # Should not happen

		player_run_state.VisitedNodeIDs.clear()
		player_run_state.VisitedNodeIDs.append(player_run_state.CurrentNodeID) # Start by visiting the start node
		player_run_state.CurrentDepth = 0 # Initialize current depth for new dungeon
		should_generate_new_dungeon = false
		# Grant a dice roll for starting a new dungeon (Rule #1)
		get_node("/root/DiceManager").enable_roll()
	elif game_manager.is_additional_exploration_mode:
		print("DEBUG: MapManager: Additional exploration mode. Reconstructing dungeon.")
		# 시드는 유지되므로, dungeon_data는 이미 생성되어 있음.
		# VisitedNodeIDs 초기화 (현재 탐험의 방문 노드 기록은 초기화)
		player_run_state.VisitedNodeIDs.clear()
		
		# 영구적으로 발견된 노드들을 VisitedNodeIDs에 추가하여 항상 보이게 함
		var permanently_discovered_for_dungeon = game_manager.permanently_discovered_nodes.get(game_manager.selected_dungeon_id, [])
		for node_id in permanently_discovered_for_dungeon:
			if not node_id in player_run_state.VisitedNodeIDs:
				player_run_state.VisitedNodeIDs.append(node_id)

		# [수정] 시작 노드를 자동으로 할당하지 않고 비워두어 사용자가 선택하게 함
		player_run_state.CurrentNodeID = ""
		print("DEBUG: MapManager: Additional exploration mode. Waiting for entrance selection.")

		player_run_state.CurrentDepth = 0

		# transformed_nodes 정보를 바탕으로 맵 재구성
		var cleared_dungeon_info = game_manager.cleared_dungeons.get(game_manager.selected_dungeon_id, {})
		var transformed_node_ids = cleared_dungeon_info.get("transformed_nodes", [])
		
		for node_id in transformed_node_ids:
			if dungeon_data.nodes.has(node_id):
				dungeon_data.nodes[node_id].node_type = "special" # 일반 전투 노드를 특수 노드로 변경
				print("DEBUG: MapManager: Node ", node_id, " transformed to special.")
		
		# 추가 탐험 모드에서는 주사위 굴림 기회 부여 안함 (규칙에 따라)
		# get_node("/root/DiceManager").enable_roll() # 주석 처리
func show_dungeon_map():
	print("DEBUG: MapManager: show_dungeon_map called. current_node_id: ", player_run_state.CurrentNodeID)

	# Ensure we have references to nodes on the main scene
	_get_main_scene_nodes()

	# Hide game world elements
	if is_instance_valid(player_node): player_node.visible = false
	if is_instance_valid(game_manager):
		# [수정] 모든 적 개체 숨기기
		for enemy in game_manager.enemy_nodes:
			if is_instance_valid(enemy):
				enemy.visible = false
		
		# [신규] 전장의 보물상자도 숨기기
		var chests = get_tree().get_nodes_in_group("treasure_chests") # 그룹화 필요
		for chest in chests:
			chest.visible = false
	if is_instance_valid(stage_info_hud): stage_info_hud.visible = false

	if not is_instance_valid(ui_manager):
		printerr("MapManager: UIManager is not valid!")
		return

	var dungeon_map_instance = dungeon_map_scene.instantiate()
	dungeon_map_instance.dungeon_data = dungeon_data
	dungeon_map_instance.current_node_id = player_run_state.CurrentNodeID
	dungeon_map_instance.player_run_state = player_run_state
	dungeon_map_instance.dungeon_seed = dungeon_seed # Pass the seed to the map
	dungeon_map_instance.is_dev_mode = game_manager.is_developer_mode # Pass dev mode flag
	dungeon_map_instance.node_activated.connect(_on_dungeon_node_activated)

	ui_manager.show_screen(UIManager.Screen.DUNGEON_MAP, dungeon_map_instance)
	print("DEBUG: MapManager: UIManager requested to show DungeonMap.")

	update_dungeon_progress_hud()

# [신규] 지도 화면을 닫고 월드 요소를 다시 표시
func hide_dungeon_map():
	print("DEBUG: MapManager: hide_dungeon_map called.")
	_get_main_scene_nodes()
	
	if is_instance_valid(player_node): player_node.visible = true
	if is_instance_valid(game_manager):
		# [수정] 모든 적 개체 다시 표시 (살아있는 개체만 표시하거나 전체 표시 후 사망 로직에 맡김)
		for enemy in game_manager.enemy_nodes:
			if is_instance_valid(enemy):
				# 체력이 남아있는 적만 다시 보이게 함 (사망한 적 잔상 방지)
				if enemy.current_stats.get_stat("health").current_value > 0:
					enemy.visible = true
	if is_instance_valid(stage_info_hud): stage_info_hud.visible = true
	
	if is_instance_valid(ui_manager):
		ui_manager.show_screen(UIManager.Screen.BATTLE_HUD)

func _on_dungeon_node_activated(node_id: String):
	print("DEBUG: MapManager: Node activation sequence started for: ", node_id)
	
	if not dungeon_data.nodes.has(node_id):
		printerr("ERROR: MapManager: Node ID '" + node_id + "' not found in dungeon data!")
		return
		
	var selected_node: DungeonNode = dungeon_data.nodes[node_id]
	print("DEBUG: MapManager: Node details - Type: ", selected_node.node_type, ", Depth: ", selected_node.depth)
	
	# [수정] 월드 요소 복구가 포함된 함수 호출
	hide_dungeon_map()
	print("DEBUG: MapManager: Dungeon map hidden.")
	
	# Tell GameManager to prepare the battle
	if is_instance_valid(game_manager):
		# Grant dice roll if the node is a special type (Rule #2)
		if selected_node.node_type == "rest" or selected_node.node_type == "shop" or selected_node.node_type == "special":
			var dice_mgr = get_node_or_null("/root/DiceManager")
			if dice_mgr:
				dice_mgr.enable_roll()
				print("DEBUG: MapManager: 특수 노드 주사위 기회 부여 완료.")

		print("DEBUG: MapManager: Calling game_manager.prepare_dungeon_battle...")
		game_manager.prepare_dungeon_battle(selected_node)
	else:
		printerr("ERROR: MapManager: game_manager is invalid!")

# [신규] 노드 클리어 처리 (전투 승리 또는 이벤트 완료 시 호출)
func clear_node(node_id: String):
	if not dungeon_data.nodes.has(node_id):
		return
		
	var node_data: DungeonNode = dungeon_data.nodes[node_id]
	player_run_state.CurrentNodeID = node_id
	if not node_id in player_run_state.VisitedNodeIDs:
		player_run_state.VisitedNodeIDs.append(node_id)
	player_run_state.CurrentDepth = node_data.depth
	
	# [이동] 탐험 보너스: 5개 노드 방문마다 주사위 굴림 기회 부여
	if player_run_state.VisitedNodeIDs.size() > 0 and player_run_state.VisitedNodeIDs.size() % 5 == 0:
		get_node("/root/DiceManager").enable_roll()
		print("DEBUG: MapManager: 탐험 보너스! 5번째 노드 방문으로 주사위 굴림 기회 획득.")
		
	update_dungeon_progress_hud()
	print("DEBUG: MapManager: Node cleared: ", node_id)

func update_dungeon_progress_hud():
	if not is_instance_valid(stage_info_hud):
		return

	var current_node_id = player_run_state.CurrentNodeID
	if not dungeon_data.nodes.has(current_node_id):
		return

	var current_node: DungeonNode = dungeon_data.nodes[current_node_id]
	stage_info_hud.update_progress(current_node.depth, dungeon_max_depth)

func set_should_generate_new_dungeon(value: bool, preserve_seed: bool = false):
	should_generate_new_dungeon = value
	if not preserve_seed:
		dungeon_seed = 0 # 0을 초기값으로 사용

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

func get_current_dungeon_visited_node_ids() -> Array:
	return player_run_state.VisitedNodeIDs

func select_transformed_nodes() -> Array:
	var normal_nodes = []
	for node_id in dungeon_data.nodes:
		var node = dungeon_data.nodes[node_id]
		if node.node_type == "normal":
			normal_nodes.append(node_id)

	if normal_nodes.size() < 2:
		return [] # Not enough normal nodes to transform

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var transformed_nodes = []
	# Select first node
	var first_node_index = rng.randi_range(0, normal_nodes.size() - 1)
	transformed_nodes.append(normal_nodes[first_node_index])
	normal_nodes.remove_at(first_node_index) # Remove to ensure uniqueness

	# Select second node
	var second_node_index = rng.randi_range(0, normal_nodes.size() - 1)
	transformed_nodes.append(normal_nodes[second_node_index])

	return transformed_nodes

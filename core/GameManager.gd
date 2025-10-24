# GameManager.gd
# 역할: 게임의 전체적인 흐름과 상태를 관리하는 중앙 관리자입니다。
extends Node
# Force recompilation - Gemini (Attempt 2)

# =============================================================================
# 시그널 (Signals)
# =============================================================================
signal battle_started
signal battle_ended(win: bool)




enum GamePhase {
	MAIN_MENU, CHARACTER_SELECT, TOWN, PREPARE,
	DESTINY_DESIGN, # 운명 설계
	COMBAT, BATTLE_END, LOOT_OFFER
}
var current_game_phase: GamePhase

# =============================================================================
# 참조 변수 (References)
# =============================================================================
var battle_manager: Node
var player_node: Character
var enemy_node: Character
var ui_manager: UIManager
var stage_info_hud: Control
var scene_manager: SceneManager
var player_manager: PlayerManager
var dice_manager: DiceManager # Reference to DiceManager

func _ready():
	dice_manager = get_node("/root/DiceManager") # Initialize DiceManager reference

# --- 게임 상태 변수 ---
var is_developer_mode: bool = false
var is_additional_exploration_mode: bool = false
var selected_dungeon_id: int = 0
var current_battle_count: int = 0
var current_stage: int = 1
var current_battle_node_type: String = ""
var current_dungeon_node: DungeonNode # Store the current dungeon node for battle context
var cleared_dungeons: Dictionary = {} # 각 던전의 dungeon_id별로 seed와 transformed_nodes를 저장
var permanently_discovered_nodes: Dictionary = {} # 던전 ID별로 영구적으로 발견된 노드 ID 목록을 저장
const BOSS_BATTLE_COUNT = 8

# Enemy scene and data mapping
const ENEMY_SCENES = {
	"battle": preload("res://characters/enemy/Enemy.tscn"),
	"elite": preload("res://characters/enemy/EliteEnemy.tscn"),
	"boss": preload("res://characters/enemy/BossEnemy.tscn"),
}
const ENEMY_DATA = {
	"battle": preload("res://resources/characters/enemy/Goblin.tres"),
	"elite": preload("res://resources/characters/enemy/EliteGoblin.tres"),
	"boss": preload("res://resources/characters/enemy/BossGoblin.tres"),
}

func _get_enemy_data_for_node_type(node_type: String) -> Dictionary:
	var enemy_scene = ENEMY_SCENES.get(node_type, ENEMY_SCENES.battle) # Default to normal battle enemy
	var enemy_data_res = ENEMY_DATA.get(node_type, ENEMY_DATA.battle) # Default to normal battle enemy data
	
	# Load and duplicate the CharacterData resource
	var enemy_character_data = (enemy_data_res as CharacterData).duplicate(true)
	
	return {"scene": enemy_scene, "data": enemy_character_data}

const DUNGEON_CONFIGS = {
	1: {
		"min_layers": 6,
		"max_layers": 8,
		"special_node_count": 1,
		"has_elites": false,
		"has_boss": true,
	},
	2: {
		"min_layers": 8,
		"max_layers": 10,
		"special_node_count": 1,
		"has_elites": true,
		"has_boss": true,
	},
	3: {
		"min_layers": 12,
		"max_layers": 14,
		"special_node_count": 2,
		"has_elites": true,
		"has_boss": true,
	},
}


# const DungeonGenerator = preload("res://core/dungeon/DungeonGenerator.gd") # Removed to fix warning

# =============================================================================
# 초기화 함수 (Initialization)
# =============================================================================



func initialize_game_scene(player: Character, enemy: Character, battle_mgr: Node, ui_mgr: UIManager, stage_hud: Control, scene_mgr: SceneManager, player_mgr: PlayerManager):
	print("DEBUG: GameManager: initialize_game_scene called.")
	print("GameManager: 게임 씬 초기화 중...")
	player_node = player
	enemy_node = enemy
	var enemy_character_data = (load("res://resources/characters/enemy/Goblin.tres") as CharacterData).duplicate(true)
	print("DEBUG: GameManager: Enemy CharacterData loaded. Name: ", enemy_character_data.character_name)
	print("DEBUG: GameManager: Enemy CharacterData health base_value: ", enemy_character_data.base_stats.health.base_value)
	print("DEBUG: GameManager: Enemy CharacterData attack_power base_value: ", enemy_character_data.base_stats.attack_power.base_value)
	print("DEBUG: GameManager: Enemy CharacterData defense base_value: ", enemy_character_data.base_stats.defense.base_value)
	enemy_node.initialize(enemy_character_data)
	battle_manager = battle_mgr
	ui_manager = ui_mgr
	stage_info_hud = stage_hud
	scene_manager = scene_mgr
	player_manager = player_mgr

	# 플레이어 노드를 기본 데이터로 초기화한 후, PlayerManager의 세션 스탯으로 즉시 업데이트합니다.
	if player_node and player_manager and player_manager.player_data:
		player_node.initialize(player_manager.player_data)
		player_node.update_stats_from_player_manager(player_manager)
		print("DEBUG: GameManager: Player node initialized and stats synced with PlayerManager.")

	if not is_instance_valid(ui_mgr):
		printerr("GameManager: UIManager가 유효하지 않습니다!")
		return

	# Connect damage signals
	if ui_manager and ui_manager.battle_hud:
		player_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(true))
		enemy_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))
	else:
		printerr("GameManager: UIManager or BattleHUD is not valid for connecting damage signals!")

	if dice_manager.get_player_dice_pool().is_empty():
		for i in range(4):
			dice_manager.add_dice_to_pool(6)

	# Initial battle setup delegated to BattleManager
	battle_manager.prepare_battle(null, player_node, enemy_node, current_stage, current_battle_count, ui_manager, stage_info_hud)
	emit_signal("battle_ended", true)


# =============================================================================
# 게임 흐름 제어 함수 (Game Flow Control)
# =============================================================================

# NOTE: prepare_current_battle function has been moved to BattleManager.gd


# =============================================================================
# 전투 행동 시그널 핸들러
# =============================================================================

func handle_attack_stance():
	print("GameManager: 공격 자세 선택됨")
	if battle_manager: battle_manager.set_player_stance(Character.Stance.ATTACK)

func handle_defense_stance():
	print("GameManager: 방어 자세 선택됨")
	if battle_manager: battle_manager.set_player_stance(Character.Stance.DEFENSE)

func handle_dodge_stance():
	print("GameManager: 회피 자세 선택됨")
	if battle_manager: battle_manager.set_player_stance(Character.Stance.EVADE)

func use_skill_1():
	print("GameManager: 스킬 1 사용")

func use_skill_2():
	print("GameManager: 스킬 2 사용")

func handle_start_combat():
	print("GameManager: 전투 시작")
	current_game_phase = GamePhase.COMBAT
	emit_signal("battle_started")

	player_node.target = enemy_node
	enemy_node.target = player_node

	if battle_manager:
		battle_manager.start_battle(player_node, enemy_node, self)

func handle_battle_end(win: bool):
	print("GameManager: 전투 종료. 승리: ", win)
	current_game_phase = GamePhase.BATTLE_END
	emit_signal("battle_ended", win)

	if win:
		current_battle_count += 1

	

		# Grant dice roll only on elite or boss wins (moved before shortcut check)
		if current_battle_node_type == "elite" or current_battle_node_type == "boss":
			dice_manager.enable_roll()
			print("강적 처치! 주사위 굴림 기회가 부여됩니다.")

		# Check if it's the final boss of the dungeon
		# Check if it's the final boss of the dungeon
		if current_battle_node_type == "boss":
			# 던전 클리어 로직
			var map_manager = get_node("/root/MapManager")
			if map_manager and selected_dungeon_id != 0:
				# 1. 던전 클리어 정보 영구 저장
				var current_dungeon_seed = map_manager.dungeon_seed
				var transformed_nodes_to_save = map_manager.select_transformed_nodes()
				cleared_dungeons[selected_dungeon_id] = {
					"seed": current_dungeon_seed,
					"transformed_nodes": transformed_nodes_to_save
				}

				# 2. 현재 던전의 VisitedNodeIDs를 permanently_discovered_nodes에 병합
				var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
				if not permanently_discovered_nodes.has(selected_dungeon_id):
					permanently_discovered_nodes[selected_dungeon_id] = []
				for node_id in visited_node_ids:
					if not node_id in permanently_discovered_nodes[selected_dungeon_id]:
						permanently_discovered_nodes[selected_dungeon_id].append(node_id)

			# End of dungeon, show options
			ui_manager.show_end_of_dungeon_options()
			return # Stop further processing here
		# Normal win flow (not boss)
		if current_battle_count > BOSS_BATTLE_COUNT:
			# This path should ideally not be reached if boss check is correct
			get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
			current_battle_count = 0
			current_stage += 1
			scene_manager.go_to_town(true)
			return

		if player_node and player_manager and player_manager.current_player_stats:
			# Update player_manager.current_player_stats with current values from player_node
			for stat_key in player_node.stats_manager.character_stats.get_all_stat_keys():
				var player_stat = player_node.stats_manager.get_stat(stat_key)
				var persistent_stat = player_manager.current_player_stats.get_stat(stat_key)
				if player_stat and persistent_stat:
					persistent_stat.base_value = player_stat.base_value # Base value should persist if modified by Destiny Design
					persistent_stat.current_value = player_stat.current_value # Current value should persist

		print("전투 승리! 다음 로직 대기 중...")
	else:
		handle_retry()

func handle_retry():
	print("GameManager: 플레이어 사망. 메인 메뉴로 돌아갑니다.")
	# 현재 던전의 VisitedNodeIDs를 permanently_discovered_nodes에 병합
	var map_manager = get_node("/root/MapManager")
	if map_manager and selected_dungeon_id != 0:
		var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
		if not permanently_discovered_nodes.has(selected_dungeon_id):
			permanently_discovered_nodes[selected_dungeon_id] = []
		for node_id in visited_node_ids:
			if not node_id in permanently_discovered_nodes[selected_dungeon_id]:
				permanently_discovered_nodes[selected_dungeon_id].append(node_id)

	# 게임 시작 화면(메인 메뉴)으로 돌아갑니다.
	current_stage = 1
	current_battle_count = 0
	if dice_manager.player_dice_pool: dice_manager.player_dice_pool.clear()
	scene_manager.go_to_main_menu() # 메인 메뉴로 이동

func prepare_dungeon_battle(node: DungeonNode):
	if node:
		current_battle_node_type = node.node_type
		current_dungeon_node = node # Store the current dungeon node
	else:
		current_battle_node_type = "normal" # Default for non-map battles

	if not is_instance_valid(battle_manager):
		printerr("GameManager: BattleManager is not valid!")
		return
	
	# --- Dynamic Enemy Spawning ---
	var enemy_info = _get_enemy_data_for_node_type(current_battle_node_type)
	var new_enemy_scene: PackedScene = enemy_info.scene
	var new_enemy_data: CharacterData = enemy_info.data
	
	# Get the current scene root to add the new enemy
	var current_scene_root = get_tree().current_scene
	if not is_instance_valid(current_scene_root):
		printerr("GameManager: Current scene root is not valid!")
		return

	# Free the old enemy if it exists and is a child of the current scene
	if is_instance_valid(enemy_node) and enemy_node.get_parent() == current_scene_root:
		enemy_node.queue_free()
		enemy_node = null # Clear reference

	# Instantiate and add the new enemy
	var instantiated_enemy = new_enemy_scene.instantiate()
	current_scene_root.add_child(instantiated_enemy)
	instantiated_enemy.name = "Enemy" # Ensure it has the expected name for Main.gd's @onready
	
	# Set position (assuming a default position for now, or it could be passed from DungeonNode/MapManager)
	# For now, use the same position as the original enemy in Main.tscn
	instantiated_enemy.position = Vector2(800, 300) 
	
	# Initialize the new enemy
	instantiated_enemy.initialize(new_enemy_data)
	
	# Update the GameManager's enemy_node reference
	enemy_node = instantiated_enemy
	
	print("DEBUG: GameManager: Spawned new enemy: ", enemy_node.name, " with data: ", new_enemy_data.character_name)

	# Scale enemy stats based on current stage and battle count
	# For now, using a simple multiplier. This can be refined later with actual enemy data.
	var hp_multiplier = 1.0 + (current_stage - 1) * 0.1 + current_battle_count * 0.05 # Example scaling
	enemy_node.set_level(current_stage, current_battle_count, hp_multiplier)
	
	# Connect the new enemy's input_event to Main.gd's handler
	var main_scene_root = get_tree().current_scene
	if main_scene_root and main_scene_root.has_method("_on_character_input_event"):
		enemy_node.input_event.connect(Callable(main_scene_root, "_on_character_input_event").bind(enemy_node))
	else:
		printerr("GameManager: Could not connect enemy input_event. Main scene root or handler not found.")

	# Connect damage_taken signal for the new enemy
	if ui_manager and ui_manager.battle_hud:
		enemy_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))
	else:
		printerr("GameManager: UIManager or BattleHUD is not valid for connecting enemy damage signals in prepare_dungeon_battle!")

	battle_manager.prepare_battle(node, player_node, enemy_node, current_stage, current_battle_count, ui_manager, stage_info_hud)

func handle_return_to_town():
	print("GameManager: Returning to town.")
	# 현재 던전의 VisitedNodeIDs를 permanently_discovered_nodes에 병합
	var map_manager = get_node("/root/MapManager")
	if map_manager and selected_dungeon_id != 0:
		var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
		if not permanently_discovered_nodes.has(selected_dungeon_id):
			permanently_discovered_nodes[selected_dungeon_id] = []
		for node_id in visited_node_ids:
			if not node_id in permanently_discovered_nodes[selected_dungeon_id]:
				permanently_discovered_nodes[selected_dungeon_id].append(node_id)

	# Preserve dungeon for next run by preserving the seed
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true) 
	current_battle_count = 0
	current_stage = 1
	scene_manager.go_to_town(true)

func update_player_node_stats():
	if player_node and player_manager:
		player_node.update_stats_from_player_manager(player_manager)
	else:
		printerr("ERROR: GameManager: Player node or PlayerManager not valid for updating player stats.")

func handle_additional_exploration():
	print("GameManager: 추가 탐험 시작.")
	is_additional_exploration_mode = true
	# 던전 시드는 유지되므로, MapManager에서 새로운 던전을 생성하지 않도록 설정
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
	# 플레이어 위치는 시작 지점으로, 이번 탐험의 방문 노드 기록은 초기화
	# 이 부분은 MapManager에서 맵 로드 시 처리될 예정
	scene_manager.start_dungeon(selected_dungeon_id, true)

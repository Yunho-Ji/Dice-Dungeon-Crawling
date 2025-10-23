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
	    enemy_node.initialize(load("res://resources/characters/enemy/Goblin.tres")) # 임시: 적 캐릭터 초기화
	    battle_manager = battle_mgr	ui_manager = ui_mgr
	stage_info_hud = stage_hud
	scene_manager = scene_mgr
	player_manager = player_mgr

	# 플레이어 스탯을 PlayerManager에서 가져와 설정
	if player_node and player_manager and player_manager.player_data:
		player_node.initialize(player_manager.player_data)
		print("GameManager: Player stats loaded from PlayerManager: ", player_manager.player_data.character_name)

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

		if player_node:
			var new_hp = min(player_node.stats_manager.get_stat("health").base_value, player_node.stats_manager.get_stat("health").computed_value + player_node.stats_manager.get_stat("recovery_power").computed_value) # Assuming recovery_power is a stat
			player_node.stats_manager.get_stat("health").base_value = new_hp
			player_node.update_hp_label()

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

func handle_additional_exploration():
	print("GameManager: 추가 탐험 시작.")
	is_additional_exploration_mode = true
	# 던전 시드는 유지되므로, MapManager에서 새로운 던전을 생성하지 않도록 설정
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
	# 플레이어 위치는 시작 지점으로, 이번 탐험의 방문 노드 기록은 초기화
	# 이 부분은 MapManager에서 맵 로드 시 처리될 예정
	scene_manager.start_dungeon(selected_dungeon_id, true)

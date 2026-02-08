# GameManager.gd
# 역할: 게임의 전체적인 흐름과 상태를 관리하는 중앙 관리자입니다。
extends Node

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
var dice_manager: DiceManager

func _ready():
	dice_manager = get_node("/root/DiceManager")

# --- 게임 상태 변수 ---
var is_developer_mode: bool = false
var is_additional_exploration_mode: bool = false
var selected_dungeon_id: int = 0
var current_battle_count: int = 0
var current_stage: int = 1
var current_battle_node_type: String = ""
var current_dungeon_node: DungeonNode
var cleared_dungeons: Dictionary = {}
var permanently_discovered_nodes: Dictionary = {}
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
const EVENT_POPUP_SCENE = preload("res://ui/dungeon/EventPopup.tscn")

func _get_enemy_data_for_node_type(node_type: String) -> Dictionary:
	var enemy_scene = ENEMY_SCENES.get(node_type, ENEMY_SCENES.battle)
	var enemy_data_res = ENEMY_DATA.get(node_type, ENEMY_DATA.battle)
	var enemy_character_data = (enemy_data_res as CharacterData).duplicate(true)
	return {"scene": enemy_scene, "data": enemy_character_data}

const DUNGEON_CONFIGS = {
	1: { "min_layers": 6, "max_layers": 8, "special_node_count": 1, "has_elites": false, "has_boss": true },
	2: { "min_layers": 8, "max_layers": 10, "special_node_count": 1, "has_elites": true, "has_boss": true },
	3: { "min_layers": 12, "max_layers": 14, "special_node_count": 2, "has_elites": true, "has_boss": true },
}

func initialize_game_scene(player: Character, enemy: Character, battle_mgr: Node, ui_mgr: UIManager, stage_hud: Control, scene_mgr: SceneManager, player_mgr: PlayerManager):
	print("DEBUG: GameManager: initialize_game_scene called.")
	player_node = player
	enemy_node = enemy
	var enemy_character_data = (load("res://resources/characters/enemy/Goblin.tres") as CharacterData).duplicate(true)
	enemy_node.initialize(enemy_character_data)
	battle_manager = battle_mgr
	ui_manager = ui_mgr
	stage_info_hud = stage_hud
	scene_manager = scene_mgr
	player_manager = player_mgr

	if player_node and player_manager and player_manager.player_data:
		player_node.initialize(player_manager.player_data)
		player_node.update_stats_from_player_manager(player_manager)

	if ui_manager and ui_manager.battle_hud:
		player_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(true))
		enemy_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))

	if dice_manager.get_player_dice_pool().is_empty():
		for i in range(4):
			dice_manager.add_dice_to_pool(6)

	battle_manager.prepare_battle(null, player_node, enemy_node, current_stage, current_battle_count, ui_manager, stage_info_hud)
	emit_signal("battle_ended", true)

func handle_attack_stance():
	if battle_manager: battle_manager.set_player_stance(Character.Stance.ATTACK)

func handle_defense_stance():
	if battle_manager: battle_manager.set_player_stance(Character.Stance.DEFENSE)

func handle_dodge_stance():
	if battle_manager: battle_manager.set_player_stance(Character.Stance.EVADE)

func use_skill_1():
	print("GameManager: 스킬 1 사용")

func use_skill_2():
	print("GameManager: 스킬 2 사용")

func handle_start_combat():
	current_game_phase = GamePhase.COMBAT
	emit_signal("battle_started")
	player_node.target = enemy_node
	enemy_node.target = player_node
	if battle_manager: battle_manager.start_battle(player_node, enemy_node, self)

func handle_battle_end(win: bool):
	current_game_phase = GamePhase.BATTLE_END
	emit_signal("battle_ended", win)
	if win:
		current_battle_count += 1
		
		# 엘리트/보스 승리 시 주사위 보상 로직 트리거
		if current_battle_node_type == "elite" or current_battle_node_type == "boss":
			_trigger_dice_reward()
			
		if current_battle_node_type == "boss":
			var map_manager = get_node("/root/MapManager")
			if map_manager and selected_dungeon_id != 0:
				cleared_dungeons[selected_dungeon_id] = { "seed": map_manager.dungeon_seed, "transformed_nodes": map_manager.select_transformed_nodes() }
				var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
				if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
				for node_id in visited_node_ids:
					if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
			ui_manager.show_end_of_dungeon_options()
			return
		if player_node and player_manager and player_manager.current_player_stats:
			# stats_manager -> current_stats 변경
			for stat_key in player_node.current_stats.get_all_stat_keys():
				var player_stat = player_node.current_stats.get_stat(stat_key)
				var persistent_stat = player_manager.current_player_stats.get_stat(stat_key)
				if player_stat and persistent_stat:
					persistent_stat.base_value = player_stat.base_value
					persistent_stat.current_value = player_stat.current_value
	else:
		handle_retry()

func handle_retry():
	var map_manager = get_node("/root/MapManager")
	if map_manager and selected_dungeon_id != 0:
		var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
		if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
		for node_id in visited_node_ids:
			if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
	current_stage = 1
	current_battle_count = 0
	if dice_manager.player_dice_pool: dice_manager.player_dice_pool.clear()
	scene_manager.go_to_main_menu()

func prepare_dungeon_battle(node: DungeonNode):
	if node:
		current_battle_node_type = node.node_type
		current_dungeon_node = node
	else:
		current_battle_node_type = "normal"

	if not is_instance_valid(battle_manager):
		printerr("GameManager: BattleManager is not valid!")
		return

	var map_manager = get_node("/root/MapManager")
	var is_revisit = false
	if map_manager and permanently_discovered_nodes.has(selected_dungeon_id):
		if node.node_id in permanently_discovered_nodes[selected_dungeon_id]:
			is_revisit = true

	# --- 특수(함정) 노드 처리 ---
	# 시작 지점(start)은 평화롭게 통과, 'special'은 함정 이벤트 발생
	if current_battle_node_type == "start":
		print("GameManager: 던전 시작 지점입니다. 평화롭게 통과합니다.")
		handle_battle_end(true)
		return
		
	if current_battle_node_type == "special":
		if is_revisit:
			print("GameManager: [빈 방] 이미 사용된 특수 노드입니다.")
			handle_battle_end(true)
		else:
			# [개선] 특수 노드 진입 시 이벤트 무작위 결정 (기획 준수)
			var event_roll = randf()
			if event_roll < 0.3: # 30% 함정
				_show_trap_event()
			elif event_roll < 0.6: # 30% 보물상자
				_show_treasure_event()
			elif event_roll < 0.8: # 20% 제단 (대가성 보상)
				_show_altar_event()
			else: # 20% 성소 (순수 은총)
				_show_sanctuary_event()
		return

	var enemy_info = _get_enemy_data_for_node_type(current_battle_node_type)
	var new_enemy_scene: PackedScene = enemy_info.scene
	var new_enemy_data: CharacterData = enemy_info.data
	var current_scene_root = get_tree().current_scene
	if is_instance_valid(enemy_node) and enemy_node.get_parent() == current_scene_root:
		enemy_node.queue_free()
		enemy_node = null

	var instantiated_enemy = new_enemy_scene.instantiate()
	current_scene_root.add_child(instantiated_enemy)
	instantiated_enemy.name = "Enemy"
	instantiated_enemy.position = Vector2(800, 300) 
	instantiated_enemy.initialize(new_enemy_data)
	enemy_node = instantiated_enemy
	
	var hp_multiplier = 1.0 + (current_stage - 1) * 0.1 + current_battle_count * 0.05
	
	if is_revisit:
		print("GameManager: [잔당 소탕] 적 약화.")
		hp_multiplier *= 0.5
		if current_battle_node_type == "elite" or current_battle_node_type == "boss":
			enemy_node.is_boss = false
			enemy_node.scale = Vector2(0.8, 0.8)

	enemy_node.set_level(current_stage, current_battle_count, hp_multiplier)
	
	if current_scene_root.has_method("_on_character_input_event"):
		enemy_node.input_event.connect(Callable(current_scene_root, "_on_character_input_event").bind(enemy_node))
	if ui_manager and ui_manager.battle_hud:
		enemy_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))

	battle_manager.prepare_battle(node, player_node, enemy_node, current_stage, current_battle_count, ui_manager, stage_info_hud)

func _trigger_dice_reward():
	var new_dice_sides = 8 if current_battle_node_type == "elite" else 12
	print("GameManager: 주사위 보상 획득 - D", new_dice_sides)
	
	# 보상을 즉시 주사위 매니저의 대기열에 추가 (UI 팝업 없음)
	if dice_manager.has_method("add_pending_reward"):
		dice_manager.add_pending_reward(new_dice_sides)
	else:
		print("DiceManager에 add_pending_reward 메서드가 없습니다.")

	# 보상 획득 후 운명 설계(주사위 굴리기) 활성화
	dice_manager.enable_roll()

func _show_trap_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	get_tree().current_scene.add_child(popup)
	var agi = 10
	if player_node and player_node.current_stats: 
		var stat = player_node.current_stats.get_stat("attack_speed")
		if stat: agi = stat.computed_value
	# 범용 이벤트 설정 호출 (함정)
	popup.setup_event(popup.EventType.TRAP, 15, 20, agi)
	popup.event_completed.connect(_on_event_completed.bind(popup))

# [신규] 보물상자 이벤트 처리
func _show_treasure_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	get_tree().current_scene.add_child(popup)
	
	# 범용 이벤트 설정 호출 (보물상자)
	popup.setup_event(popup.EventType.TREASURE) 
	popup.event_completed.connect(_on_event_completed.bind(popup))

# [신규] 제단 이벤트 처리 (대가성 보상)
func _show_altar_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	get_tree().current_scene.add_child(popup)
	
	# 범용 이벤트 설정 호출 (제단)
	popup.setup_event(popup.EventType.ALTAR) 
	popup.event_completed.connect(_on_event_completed.bind(popup))

# [신규] 성소 이벤트 처리 (순수 은총)
func _show_sanctuary_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	get_tree().current_scene.add_child(popup)
	
	# 범용 이벤트 설정 호출 (성소)
	popup.setup_event(popup.EventType.SANCTUARY)
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _on_event_completed(popup_instance):
	popup_instance.queue_free()
	handle_battle_end(true)

func handle_return_to_town():
	var map_manager = get_node("/root/MapManager")
	if map_manager and selected_dungeon_id != 0:
		var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
		if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
		for node_id in visited_node_ids:
			if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true) 
	current_battle_count = 0
	current_stage = 1
	scene_manager.go_to_town(true)

func update_player_node_stats():
	if player_node and player_manager: player_node.update_stats_from_player_manager(player_manager)

func handle_additional_exploration():
	is_additional_exploration_mode = true
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
	scene_manager.start_dungeon(selected_dungeon_id, true)

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
	READY_TO_BATTLE, # 전투 시작 대기 중
	COMBAT, BATTLE_END, LOOT_OFFER
}
var current_game_phase: GamePhase

# =============================================================================
# 참조 변수 (References)
# =============================================================================
var battle_manager: Node
var player_node: Character
var enemy_node: Character # 하위 호환성을 위해 첫 번째 적 유지
var enemy_nodes: Array[Character] = []
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
	
	# 리소스 로드 실패 방지 (Memories 반영)
	if not enemy_data_res:
		enemy_data_res = load("res://resources/characters/enemy/Goblin.tres")
		
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
	
	# 초기화 시 받은 enemy를 배열에 추가
	enemy_node = enemy
	enemy_nodes = [enemy_node]
	
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
		for e in enemy_nodes:
			e.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))

	if dice_manager.get_player_dice_pool().is_empty():
		for i in range(4):
			dice_manager.add_dice_to_pool(6)

	battle_manager.prepare_battle(null, player_node, enemy_nodes, current_stage, current_battle_count, ui_manager, stage_info_hud)
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
	
	# 플레이어의 타겟 설정 (첫 번째 적)
	if not enemy_nodes.is_empty():
		player_node.target = enemy_nodes[0]
	
	# 모든 적의 타겟을 플레이어로 설정
	for enemy in enemy_nodes:
		if is_instance_valid(enemy):
			enemy.target = player_node
			
	if battle_manager: 
		battle_manager.start_battle(player_node, enemy_nodes, self)

const TREASURE_CHEST_SCENE = preload("res://ui/elements/TreasureChest.tscn")

func handle_battle_end(win: bool, spawn_chest: bool = true):
	current_game_phase = GamePhase.BATTLE_END
	emit_signal("battle_ended", win)
	if win:
		current_battle_count += 1
		
		# [수정] 승리 시 전리품 생성 (파라미터에 따라 상자 스폰 여부 결정)
		var loot = _generate_loot_for_node(current_battle_node_type)
		if spawn_chest and not loot.is_empty():
			_spawn_treasure_chest(loot)
		
		if current_battle_node_type == "boss":
			# 보스 클리어 로직 (기존 유지)
			var map_manager = get_node("/root/MapManager")
			if map_manager and selected_dungeon_id != 0:
				cleared_dungeons[selected_dungeon_id] = { "seed": map_manager.dungeon_seed, "transformed_nodes": map_manager.select_transformed_nodes() }
				var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
				if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
				for node_id in visited_node_ids:
					if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
			# 전리품 확인 후 보스 클리어 UI가 뜨도록 유도 (현재는 즉시 호출하지만, 실제로는 전리품 확인 후가 좋음)
			# 일단 기존 로직 유지
			ui_manager.show_end_of_dungeon_options()
			return
		
		if player_node and player_manager and player_manager.current_player_stats:
			# [수정] 수정자(Modifiers)를 포함한 모든 성장 데이터를 통째로 동기화하여 보존
			player_manager.current_player_stats.sync_from(player_node.current_stats)
			print("GameManager: 플레이어 성장 데이터를 성공적으로 보존했습니다.")
	else:
		handle_retry()

# [신규] 노드 타입에 따른 전리품 생성
func _generate_loot_for_node(node_type: String) -> Dictionary:
	var loot = {
		"gold": 0,
		"items": [], # Array[Dictionary] : {"id": ..., "is_identified": false}
		"dice": [],
		"is_boss": (node_type == "boss")
	}
	
	match node_type:
		"battle":
			loot.gold = randi_range(20, 50)
			if randf() < 0.3: # 30% 확률로 아이템
				loot.items.append(_pick_random_item_with_weight())
		"elite":
			loot.gold = randi_range(100, 200)
			loot.dice.append(8)
			loot.items.append(_pick_random_item_with_weight(Apeloot.Rarity.UNCOMMON))
		"boss":
			loot.gold = randi_range(500, 1000)
			loot.dice.append(12)
			loot.items.append(_pick_random_item_with_weight(Apeloot.Rarity.RARE))
			loot.items.append(_pick_random_item_with_weight(Apeloot.Rarity.UNCOMMON))
		"special":
			# 특수 노드의 전리품은 이벤트 성격에 따라 차등 지급
			loot.gold = randi_range(50, 150)
			if randf() < 0.5: # 50% 확률로 아이템 포함
				loot.items.append(_pick_random_item_with_weight())
	
	return loot

## 가중치 기반 아이템 선택 (크기 상관없이 가치 보존)
func _pick_random_item_with_weight(min_rarity: int = Apeloot.Rarity.COMMON) -> Dictionary:
	var possible_items = []
	for id in Apeloot.items.keys():
		var data = Apeloot.items[id]
		if data.get("rarity", 0) >= min_rarity:
			# 기획: 1x1 등 작은 아이템은 희귀도가 높을 때 더 높은 선택 가중치를 가질 수도 있음 (현재는 단순 랜덤)
			possible_items.append(id)
	
	var selected_id = possible_items.pick_random() if not possible_items.is_empty() else "ketchup"
	return {"id": selected_id, "is_identified": false}

# [신규] 전리품 화면 표시
func _show_loot_offer(loot: Dictionary):
	if ui_manager:
		ui_manager.show_screen(UIManager.Screen.LOOT_OFFER)
		var loot_screen = ui_manager.screen_nodes.get(UIManager.Screen.LOOT_OFFER)
		if loot_screen:
			loot_screen.setup(loot)

# [신규] 전장에 상호작용 가능한 보물상자 생성
func _spawn_treasure_chest(loot: Dictionary):
	var chest = TREASURE_CHEST_SCENE.instantiate()
	get_tree().current_scene.add_child(chest)
	
	# 마지막 적이 있던 위치 근처로 배치 (기본값 설정)
	var spawn_pos = Vector2(800, 300) 
	chest.global_position = spawn_pos
	chest.setup(loot)
	print("GameManager: 전리품 보물상자가 생성되었습니다.")

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
	# 시작 지점(start)은 아무 효과 없이 통과 (이미 초기 시퀀스에서 운명 설계 수행됨)
	if current_battle_node_type == "start":
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

	# 기존 적들 제거
	for e in enemy_nodes:
		if is_instance_valid(e):
			e.queue_free()
	enemy_nodes.clear()
	enemy_node = null

	var current_scene_root = get_tree().current_scene
	var spawn_list = [] # 생성할 적 정보 리스트 [{"scene": ..., "data": ...}, ...]

	# --- 노드 타입별 적 구성 결정 ---
	match current_battle_node_type:
		"elite":
			spawn_list.append(_get_enemy_data_for_node_type("elite"))
			# 엘리트 노드는 최소 2마리, 최대 3마리 (엘리트 1 + 쫄 1~2)
			var minion_count = 1 if randf() < 0.5 else 2
			for m in range(minion_count):
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
		"boss":
			spawn_list.append(_get_enemy_data_for_node_type("boss"))
			# 보스는 위엄을 위해 일단 단독 출현 (필요 시 쫄 추가 가능)
		_: # "battle" 또는 기타 일반 노드
			spawn_list.append(_get_enemy_data_for_node_type("battle"))
			var roll = randf()
			if roll < 0.2: # 20% 확률로 3마리
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
			elif roll < 0.5: # 추가 30% (총 50%) 확률로 2마리
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
			# 나머지 50% 확률로 1마리

	# --- 적 생성 및 초기화 ---
	for i in range(spawn_list.size()):
		var info = spawn_list[i]
		var instantiated_enemy = info.scene.instantiate()
		current_scene_root.add_child(instantiated_enemy)
		instantiated_enemy.name = "Enemy_" + str(i)
		instantiated_enemy.initialize(info.data)
		
		# 첫 번째 적을 메인 enemy_node로 유지 (기존 UI 연동용)
		if i == 0:
			enemy_node = instantiated_enemy
			
		enemy_nodes.append(instantiated_enemy)
		
		# 시그널 연결
		if current_scene_root.has_method("_on_character_input_event"):
			instantiated_enemy.input_event.connect(Callable(current_scene_root, "_on_character_input_event").bind(instantiated_enemy))
		if ui_manager and ui_manager.battle_hud:
			instantiated_enemy.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))

	# --- 스탯 조정 (난이도 반영) ---
	var hp_multiplier = 1.0 + (current_stage - 1) * 0.1 + current_battle_count * 0.05
	
	if is_revisit:
		print("GameManager: [잔당 소탕] 적 약화.")
		hp_multiplier *= 0.5

	for e in enemy_nodes:
		var final_multiplier = hp_multiplier
		# 적이 여러 마리일 때 개별 체력 약간 하향 (밸런스)
		if enemy_nodes.size() > 1 and not e.is_boss:
			final_multiplier *= 0.8
		e.set_level(current_stage, current_battle_count, final_multiplier)

	current_game_phase = GamePhase.READY_TO_BATTLE # [신규] 전투 준비 완료 상태로 설정
	battle_manager.prepare_battle(node, player_node, enemy_nodes, current_stage, current_battle_count, ui_manager, stage_info_hud)


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
	# 이벤트의 결과에 따라 상자 스폰 여부를 결정할 수 있음
	# 예: popup_instance.is_reward_granted()
	var should_spawn_loot = true 
	
	popup_instance.queue_free()
	handle_battle_end(true, should_spawn_loot)

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

## 던전 탐험 시작 시 최초로 실행되는 시퀀스 (운명 설계)
func start_dungeon_initial_sequence():
	print("GameManager: 던전 초기 시퀀스 시작 - 운명 설계 호출")
	current_game_phase = GamePhase.PREPARE # 준비 단계로 설정
	if ui_manager:
		ui_manager.show_screen(UIManager.Screen.DESTINY_DESIGN)

func handle_additional_exploration():
	is_additional_exploration_mode = true
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
	scene_manager.start_dungeon(selected_dungeon_id, true)

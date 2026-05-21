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
	
	# 마을 시간 패널티 시그널 연결
	var town_manager = get_node_or_null("/root/TownManager")
	if town_manager:
		if not town_manager.penalties_applied.is_connected(_on_town_penalty_applied):
			town_manager.penalties_applied.connect(_on_town_penalty_applied)
		if not town_manager.time_updated.is_connected(_on_town_time_updated):
			town_manager.time_updated.connect(_on_town_time_updated)
		if not town_manager.multiple_enemies_penalty_applied.is_connected(func(): _on_town_penalty_applied("multiple_enemies")):
			town_manager.multiple_enemies_penalty_applied.connect(func(): _on_town_penalty_applied("multiple_enemies"))
		if not town_manager.stronger_enemies_penalty_applied.is_connected(func(): _on_town_penalty_applied("stronger_enemies")):
			town_manager.stronger_enemies_penalty_applied.connect(func(): _on_town_penalty_applied("stronger_enemies"))

# --- 게임 상태 변수 ---
var is_developer_mode: bool = false
var active_penalties: Array[String] = [] # [신규] 마을 패널티 상태

func _on_town_penalty_applied(penalty_type: String):
	if not penalty_type in active_penalties:
		active_penalties.append(penalty_type)
		print("GameManager: 마을 패널티 등록 - ", penalty_type)

func _on_town_time_updated(_time_str: String):
	# 새로운 날이 시작되면 패널티 초기화 (여관 휴식 시)
	var tm = get_node("/root/TownManager")
	if tm and tm.current_time_index == 0:
		active_penalties.clear()
		print("GameManager: 새로운 하루 시작, 모든 마을 패널티 초기화.")

var is_additional_exploration_mode: bool = false
var selected_dungeon_id: int = 0
var current_battle_count: int = 0
var current_stage: int = 1
var current_battle_node_type: String = ""
var current_dungeon_node: DungeonNode
var cleared_dungeons: Dictionary = {}
var permanently_discovered_nodes: Dictionary = {}
const BOSS_BATTLE_COUNT = 8

# 던전 설정 (MapManager 등에서 참조)
const DUNGEON_CONFIGS = {
	1: { "min_layers": 6, "max_layers": 8, "num_specials": 1, "num_elites": 0, "has_boss": true },
	2: { "min_layers": 8, "max_layers": 10, "num_specials": 1, "num_elites": 1, "has_boss": true },
	3: { "min_layers": 12, "max_layers": 14, "num_specials": 2, "num_elites": 2, "has_boss": true },
}

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
	
	# 리소스 로드 실패 방지
	if not enemy_data_res:
		enemy_data_res = load("res://resources/characters/enemy/Goblin.tres")
		
	var enemy_character_data = (enemy_data_res as CharacterData).duplicate(true)
	return {"scene": enemy_scene, "data": enemy_character_data}

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
		# [신규] 씬 생성 시 장비의 트리거 효과(ActionTriggerEffect) 재적용
		player_manager.reapply_equipment_effects(player_node)

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
		# [신규] 승리 시 전장에 남은 적 개체들 제거 (그룹 기반 확실한 제거)
		get_tree().call_group("active_enemies", "queue_free")
		enemy_nodes.clear()
		
		# [신규] 승리 시 해당 노드를 클리어 처리 (MapManager 진행 상태 갱신)
		var map_manager = get_node("/root/MapManager")
		if map_manager and current_dungeon_node:
			map_manager.clear_node(current_dungeon_node.node_id)
			
		current_battle_count += 1
		
		# [수정] 승리 시 전리품 생성 (파라미터에 따라 상자 스폰 여부 결정)
		var loot = _generate_loot_for_node(current_battle_node_type)
		if spawn_chest and not loot.is_empty():
			_spawn_treasure_chest(loot)
		
		if current_battle_node_type == "boss":
			# 보스 클리어 데이터 보존 로직 유지
			if map_manager and selected_dungeon_id != 0:
				cleared_dungeons[selected_dungeon_id] = { "seed": map_manager.dungeon_seed, "transformed_nodes": map_manager.select_transformed_nodes() }
				var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
				if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
				for node_id in visited_node_ids:
					if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
			
			if player_node and player_manager and player_manager.current_player_stats:
				player_manager.current_player_stats.sync_from(player_node.current_stats)
			
			print("GameManager: 보스 클리어 완료. 전리품 획득 후 지도를 통해 이동하거나 정비하십시오.")
			# [수정] show_end_of_dungeon_options() 호출을 제거하여 루팅을 방해하지 않음
			return
		
		if player_node and player_manager and player_manager.current_player_stats:
			player_manager.current_player_stats.sync_from(player_node.current_stats)
	else:
		handle_retry()

# [신규] 노드 타입에 따른 전리품 생성
func _generate_loot_for_node(node_type: String) -> Dictionary:
	var loot = {
		"gold": 0,
		"items": [],
		"dice": [],
		"is_boss": (node_type == "boss")
	}
	
	match node_type:
		"battle":
			loot.gold = randi_range(20, 50)
			if randf() < 0.3:
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
			loot.gold = randi_range(50, 150)
			if randf() < 0.5:
				loot.items.append(_pick_random_item_with_weight())
	
	return loot

func _pick_random_item_with_weight(min_rarity: int = Apeloot.Rarity.COMMON) -> Dictionary:
	var possible_items = []
	for id in Apeloot.items.keys():
		var data = Apeloot.items[id]
		if data.get("rarity", 0) >= min_rarity:
			possible_items.append(id)
	
	var selected_id = possible_items.pick_random() if not possible_items.is_empty() else "ketchup"
	return {"id": selected_id, "is_identified": false}

func _show_loot_offer(loot: Dictionary):
	if ui_manager:
		# [수정] LootManager에 데이터 등록
		var loot_manager = get_node("/root/LootManager")
		loot_manager.set_pending_loot(loot)
		
		ui_manager.show_screen(UIManager.Screen.LOOT_OFFER)
		var loot_screen = ui_manager.screen_nodes.get(UIManager.Screen.LOOT_OFFER)
		if loot_screen:
			loot_screen.setup(loot_manager.get_loot_data())

func _spawn_treasure_chest(loot: Dictionary):
	var chest = TREASURE_CHEST_SCENE.instantiate()
	get_tree().current_scene.add_child(chest)
	var spawn_pos = Vector2(800, 300) 
	chest.global_position = spawn_pos
	chest.setup(loot)

func handle_retry():
	var map_manager = get_node("/root/MapManager")
	if map_manager:
		map_manager.set_should_generate_new_dungeon(true)
		if selected_dungeon_id != 0:
			var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
			if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
			for node_id in visited_node_ids:
				if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
	
	var inventory = Apeloot.inventory_refs.get("player_inventory")
	if inventory:
		for item in inventory.items.duplicate():
			inventory.remove_item(item)
	
	if player_manager:
		for slot in player_manager.equipment.keys():
			player_manager.unequip_item(slot)
		if player_manager.player_data and player_manager.player_data.base_stats:
			player_manager.current_player_stats = player_manager.player_data.base_stats.duplicate(true)

	EconomyManager.set_gold(0)
	current_stage = 1
	current_battle_count = 0
	if dice_manager.player_dice_pool: dice_manager.player_dice_pool.clear()
	scene_manager.go_to_main_menu()

func prepare_dungeon_battle(node: DungeonNode):
	# [수정] 이전 노드의 적 개체들을 즉시 제거하여 특수 노드 등에서 잔상이 남지 않게 함
	for e in enemy_nodes:
		if is_instance_valid(e):
			e.queue_free()
	enemy_nodes.clear()
	enemy_node = null

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

	if current_battle_node_type == "start":
		# [핵심] 시작 노드에서는 적을 절대 소환하지 않고 즉시 종료 처리
		print("GameManager: 시작 노드에 진입했습니다. 전투가 없습니다.")
		handle_battle_end(true, false)
		return
		
	if current_battle_node_type == "special" or current_battle_node_type == "rest" or current_battle_node_type == "shop":
		if is_revisit:
			handle_battle_end(true, false)
		else:
			var event_roll = randf()
			if event_roll < 0.3:
				_show_trap_event()
			elif event_roll < 0.6:
				_show_treasure_event()
			elif event_roll < 0.8:
				_show_altar_event()
			else:
				_show_sanctuary_event()
		return

	var current_scene_root = get_tree().current_scene
	var spawn_list = []

	match current_battle_node_type:
		"elite":
			spawn_list.append(_get_enemy_data_for_node_type("elite"))
			var minion_count = 1 if randf() < 0.5 else 2
			for m in range(minion_count):
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
		"boss":
			spawn_list.append(_get_enemy_data_for_node_type("boss"))
		_: 
			spawn_list.append(_get_enemy_data_for_node_type("battle"))
			var roll = randf()
			if roll < 0.2:
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
				spawn_list.append(_get_enemy_data_for_node_type("battle"))
			elif roll < 0.5:
				spawn_list.append(_get_enemy_data_for_node_type("battle"))

	for i in range(spawn_list.size()):
		var info = spawn_list[i]
		var instantiated_enemy = info.scene.instantiate()
		current_scene_root.add_child(instantiated_enemy)
		instantiated_enemy.name = "Enemy_" + str(i)
		instantiated_enemy.initialize(info.data)
		instantiated_enemy.add_to_group("active_enemies") # [신규] 일괄 제거를 위한 그룹 등록
		if i == 0:
			enemy_node = instantiated_enemy
		enemy_nodes.append(instantiated_enemy)
		if ui_manager and ui_manager.battle_hud:
			instantiated_enemy.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false))

	var hp_multiplier = 1.0 + (current_stage - 1) * 0.1 + current_battle_count * 0.05
	if active_penalties.has("stronger_enemies"):
		hp_multiplier *= 1.2
	if is_revisit:
		hp_multiplier *= 0.5

	for e in enemy_nodes:
		var final_multiplier = hp_multiplier
		if enemy_nodes.size() > 1 and not e.is_boss:
			final_multiplier *= 0.8
		e.set_level(current_stage, current_battle_count, final_multiplier)

	current_game_phase = GamePhase.READY_TO_BATTLE
	battle_manager.prepare_battle(node, player_node, enemy_nodes, current_stage, current_battle_count, ui_manager, stage_info_hud)


func _show_trap_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	
	# [신규] 함정 유형 무작위 결정 (기획 명세 기반)
	var trap_types = ["physical", "poison", "magic", "mental"]
	var selected_type = trap_types.pick_random()
	
	var stat_key = "agi"
	var trap_name = "물리 함정"
	
	match selected_type:
		"physical": 
			stat_key = "agi"
			trap_name = "물리 함정 (낙석/화살)"
		"poison": 
			stat_key = "vit"
			trap_name = "독/가스 함정"
		"magic": 
			stat_key = "int_stat"
			trap_name = "마법 암호 함정"
		"mental": 
			stat_key = "spi"
			trap_name = "정신적 공포 함정"

	var bonus = 0
	if player_node and player_node.current_stats: 
		var stat = player_node.current_stats.get_stat(stat_key)
		if stat:
			# [공식] 스탯 10단위당 +1 보정치 (수치 * 0.1)
			bonus = int(stat.computed_value * 0.1)
	
	popup.setup_event(popup.EventType.TRAP, 15, 20, bonus)
	# 팝업 타이틀 및 설명 커스텀
	popup.title_label.text = trap_name
	
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_treasure_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	popup.setup_event(popup.EventType.TREASURE) 
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_altar_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	popup.setup_event(popup.EventType.ALTAR) 
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_sanctuary_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	popup.setup_event(popup.EventType.SANCTUARY)
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _on_event_completed(popup_instance):
	popup_instance.queue_free()
	handle_battle_end(true, false)

func handle_return_to_town():
	var map_manager = get_node("/root/MapManager")
	# 던전을 새로 생성하지 않고 기존 레이아웃(시드)을 보존함
	if map_manager:
		map_manager.set_should_generate_new_dungeon(false, true) 
	
	current_battle_count = 0
	current_stage = 1
	is_additional_exploration_mode = false
	scene_manager.go_to_town(true)

func update_player_node_stats():
	if player_node and player_manager: player_node.update_stats_from_player_manager(player_manager)

func start_dungeon_initial_sequence():
	current_game_phase = GamePhase.PREPARE
	if ui_manager:
		ui_manager.show_screen(UIManager.Screen.DESTINY_DESIGN)

func handle_additional_exploration():
	is_additional_exploration_mode = true
	get_node("/root/MapManager").set_should_generate_new_dungeon(false, true)
	scene_manager.start_dungeon(selected_dungeon_id, true)

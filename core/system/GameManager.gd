# GameManager.gd
# 역할: 게임의 전체적인 흐름과 상태를 관리하는 중앙 관리자입니다.
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
var current_game_phase: int = GamePhase.MAIN_MENU

# =============================================================================
# 참조 변수 (References)
# =============================================================================
var battle_manager: Node
var player_node: CharacterBody2D # Character -> CharacterBody2D (순환 참조 방지)
var enemy_node: CharacterBody2D
var enemy_nodes: Array[CharacterBody2D] = []
var ui_manager: Node # UIManager -> Node
var stage_info_hud: Control
var scene_manager: Node # SceneManager -> Node
var player_manager: Node # PlayerManager -> Node
var dice_manager: Node

func _ready():
	dice_manager = get_node_or_null("/root/DiceManager")
	
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
var current_dungeon_node: Resource # DungeonNode -> Resource
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
		
	var enemy_character_data = (enemy_data_res as Resource).duplicate(true)
	return {"scene": enemy_scene, "data": enemy_character_data}

func initialize_game_scene(player: Node, enemy: Node, battle_mgr: Node, ui_mgr: Node, stage_hud: Control, scene_mgr: Node, player_mgr: Node):
	print("DEBUG: GameManager: initialize_game_scene called.")
	player_node = player
	
	# 초기화 시 받은 enemy를 배열에 추가 (임시 참조 유지)
	enemy_node = enemy
	enemy_nodes = [enemy_node]
	
	battle_manager = battle_mgr
	ui_manager = ui_mgr
	stage_info_hud = stage_hud
	scene_manager = scene_mgr
	player_manager = player_mgr

	if player_node and player_manager and player_manager.player_data:
		if player_node.has_method("initialize"):
			player_node.initialize(player_manager.player_data)
		if player_node.has_method("update_stats_from_player_manager"):
			player_node.update_stats_from_player_manager(player_manager)
		# [신규] 씬 생성 시 장비의 트리거 효과(ActionTriggerEffect) 재적용
		if player_manager.has_method("reapply_equipment_effects"):
			player_manager.reapply_equipment_effects(player_node)

	if ui_manager and ui_manager.get("battle_hud"):
		var bh = ui_manager.get("battle_hud")
		if bh and is_instance_valid(player_node) and player_node.has_signal("damage_taken"):
			player_node.damage_taken.connect(Callable(bh, "_on_character_damage_taken").bind(true))
		for e in enemy_nodes:
			if is_instance_valid(e) and e.has_signal("damage_taken"):
				e.damage_taken.connect(Callable(bh, "_on_character_damage_taken").bind(false))

	if dice_manager and dice_manager.has_method("get_player_dice_pool") and dice_manager.get_player_dice_pool().is_empty():
		for i in range(4):
			dice_manager.add_dice_to_pool(6)


func handle_attack_stance():
	if battle_manager: battle_manager.set_player_stance(0) # enum Stance.ATTACK = 0

func handle_defense_stance():
	if battle_manager: battle_manager.set_player_stance(1) # enum Stance.DEFENSE = 1

func use_skill_1():
	print("GameManager: 스킬 1 사용")

func use_skill_2():
	print("GameManager: 스킬 2 사용")

func handle_start_combat():
	current_game_phase = GamePhase.COMBAT
	emit_signal("battle_started")
	
	# 플레이어의 타겟 설정 (첫 번째 적)
	if not enemy_nodes.is_empty():
		player_node.set("target", enemy_nodes[0])
	
	# 모든 적의 타겟을 플레이어로 설정
	for enemy in enemy_nodes:
		if is_instance_valid(enemy):
			enemy.set("target", player_node)
			
	if battle_manager: 
		battle_manager.start_battle(player_node, enemy_nodes, self)

const TREASURE_CHEST_SCENE = preload("res://ui/elements/TreasureChest.tscn")

func handle_battle_end(win: bool, spawn_chest: bool = true):
	current_game_phase = GamePhase.BATTLE_END
	emit_signal("battle_ended", win)
	if win:
		if is_instance_valid(player_node):
			player_node.set("target", null)
		
		enemy_node = null
		
		for enemy in enemy_nodes:
			if is_instance_valid(enemy):
				enemy.set("target", null)

		# [신규] 승리 시 전장에 남은 적 개체들 제거 (그룹 기반 확실한 제거)
		get_tree().call_group("active_enemies", "queue_free")
		enemy_nodes.clear()
		
		# [신규] 승리 시 해당 노드를 클리어 처리 (MapManager 진행 상태 갱신)
		var map_manager = get_node_or_null("/root/MapManager")
		if map_manager and current_dungeon_node:
			map_manager.clear_node(current_dungeon_node.get("node_id"))
			
		current_battle_count += 1
		
		# [수정] 승리 시 전리품 생성 (파라미터에 따라 상자 스폰 여부 결정)
		var loot = _generate_loot_for_node(current_battle_node_type)
		if spawn_chest and not loot.is_empty():
			_spawn_treasure_chest(loot)
		
		if current_battle_node_type == "boss":
			if map_manager and selected_dungeon_id != 0:
				cleared_dungeons[selected_dungeon_id] = { "seed": map_manager.get("dungeon_seed"), "transformed_nodes": map_manager.select_transformed_nodes() }
				var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
				if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
				for node_id in visited_node_ids:
					if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
			
			if player_node and player_manager and player_manager.get("current_player_stats"):
				if player_manager.get("current_player_stats").has_method("sync_from"):
					player_manager.get("current_player_stats").sync_from(player_node.get("current_stats"))
			
			print("GameManager: 보스 클리어 완료. 전리품 획득 후 지도를 통해 이동하거나 정비하십시오.")
			return
		
		if player_node and player_manager and player_manager.get("current_player_stats"):
			if player_manager.get("current_player_stats").has_method("sync_from"):
				player_manager.get("current_player_stats").sync_from(player_node.get("current_stats"))
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
			loot.items.append(_pick_random_item_with_weight(1)) # Enums.Rarity.UNCOMMON = 1
		"boss":
			loot.gold = randi_range(500, 1000)
			loot.dice.append(12)
			loot.items.append(_pick_random_item_with_weight(2)) # Enums.Rarity.RARE = 2
			loot.items.append(_pick_random_item_with_weight(1))
		"special":
			loot.gold = randi_range(50, 150)
			if randf() < 0.5:
				loot.items.append(_pick_random_item_with_weight())
	
	return loot

func _pick_random_item_with_weight(min_rarity: int = 0) -> Dictionary:
	var possible_items = []
	var dm = get_node_or_null("/root/DataManager")
	if not dm: return {"id": "test_sword_common", "is_identified": false}
	
	for id in dm.items.keys():
		var data = dm.items[id]
		var grade_str = data.get("grade", "common")
		var grade_idx = 0
		match grade_str.to_lower():
			"common": grade_idx = 0
			"uncommon": grade_idx = 1
			"rare": grade_idx = 2
			"epic": grade_idx = 3
			"legendary": grade_idx = 4
			
		if grade_idx >= min_rarity:
			possible_items.append(id)
	
	var selected_id = possible_items.pick_random() if not possible_items.is_empty() else "test_sword_common"
	return {"id": selected_id, "is_identified": false}

func _show_loot_offer(loot: Dictionary):
	if ui_manager:
		var loot_manager = get_node("/root/LootManager")
		if loot_manager:
			loot_manager.set_pending_loot(loot)
			
			if ui_manager.has_method("show_screen"):
				ui_manager.show_screen(6) # Screen.LOOT_OFFER = 6
				var loot_screen = ui_manager.get("screen_nodes").get(6)
				if loot_screen and loot_screen.has_method("setup"):
					loot_screen.setup(loot_manager.get_loot_data())

func _spawn_treasure_chest(loot: Dictionary):
	var chest = TREASURE_CHEST_SCENE.instantiate()
	get_tree().current_scene.add_child(chest)
	var spawn_pos = Vector2(800, 300) 
	chest.global_position = spawn_pos
	if chest.has_method("setup"):
		chest.setup(loot)

func handle_retry():
	var map_manager = get_node_or_null("/root/MapManager")
	if map_manager:
		map_manager.set("should_generate_new_dungeon", true)
		if selected_dungeon_id != 0:
			var visited_node_ids = map_manager.get_current_dungeon_visited_node_ids()
			if not permanently_discovered_nodes.has(selected_dungeon_id): permanently_discovered_nodes[selected_dungeon_id] = []
			for node_id in visited_node_ids:
				if not node_id in permanently_discovered_nodes[selected_dungeon_id]: permanently_discovered_nodes[selected_dungeon_id].append(node_id)
	
	if player_manager:
		var inv_script = load("res://core/inventory/InventoryData.gd")
		if inv_script:
			player_manager.set("inventory_data", inv_script.new(Vector2i(10, 5)))
		
		if player_manager.has_method("unequip_item"):
			for slot in player_manager.get("equipment").keys():
				player_manager.unequip_item(slot)
		if player_manager.get("player_data") and player_manager.get("player_data").get("base_stats"):
			player_manager.set("current_player_stats", player_manager.get("player_data").get("base_stats").duplicate(true))

	var em = get_node_or_null("/root/EconomyManager")
	if em: em.set_gold(0)
	current_stage = 1
	current_battle_count = 0
	if dice_manager and dice_manager.get("player_dice_pool"): dice_manager.get("player_dice_pool").clear()
	if scene_manager: scene_manager.go_to_main_menu()

func prepare_dungeon_battle(node: Resource):
	for e in enemy_nodes:
		if is_instance_valid(e):
			e.queue_free()
	enemy_nodes.clear()
	enemy_node = null

	if node:
		current_battle_node_type = node.get("node_type")
		current_dungeon_node = node
	else:
		current_battle_node_type = "normal"

	if not is_instance_valid(battle_manager):
		printerr("GameManager: BattleManager is not valid!")
		return

	var map_manager = get_node_or_null("/root/MapManager")
	var is_revisit = false
	if map_manager and permanently_discovered_nodes.has(selected_dungeon_id):
		if node and node.get("node_id") in permanently_discovered_nodes[selected_dungeon_id]:
			is_revisit = true
		
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
		if instantiated_enemy.has_method("initialize"):
			instantiated_enemy.initialize(info.data)
		instantiated_enemy.add_to_group("active_enemies")
		if i == 0:
			enemy_node = instantiated_enemy
		enemy_nodes.append(instantiated_enemy)
		if ui_manager and ui_manager.get("battle_hud"):
			if is_instance_valid(instantiated_enemy) and instantiated_enemy.has_signal("damage_taken"):
				instantiated_enemy.damage_taken.connect(Callable(ui_manager.get("battle_hud"), "_on_character_damage_taken").bind(false))

	var hp_multiplier = 1.0 + (current_stage - 1) * 0.1 + current_battle_count * 0.05
	if active_penalties.has("stronger_enemies"):
		hp_multiplier *= 1.2
	if is_revisit:
		hp_multiplier *= 0.5

	for e in enemy_nodes:
		var final_multiplier = hp_multiplier
		if enemy_nodes.size() > 1 and not e.get("is_boss"):
			final_multiplier *= 0.8
		if e.has_method("set_level"):
			e.set_level(current_stage, current_battle_count, final_multiplier)

	current_game_phase = GamePhase.READY_TO_BATTLE
	if battle_manager.has_method("prepare_battle"):
		battle_manager.prepare_battle(node, player_node, enemy_nodes, current_stage, current_battle_count, ui_manager, stage_info_hud)


func _show_trap_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	
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
	if player_node and player_node.get("current_stats"): 
		var stats = player_node.get("current_stats")
		if stats.has_method("get_stat"):
			var stat = stats.get_stat(stat_key)
			if stat:
				bonus = int(stat.get("computed_value") * 0.1)
	
	if popup.has_method("setup_event"):
		popup.setup_event(0, 15, 20, bonus) # EventType.TRAP = 0
	if popup.get("title_label"):
		popup.get("title_label").text = trap_name
	
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_treasure_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	if popup.has_method("setup_event"):
		popup.setup_event(1) # EventType.TREASURE = 1
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_altar_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	if popup.has_method("setup_event"):
		popup.setup_event(2) # EventType.ALTAR = 2
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _show_sanctuary_event():
	if not ui_manager: return
	var popup = EVENT_POPUP_SCENE.instantiate()
	ui_manager.add_child(popup)
	if popup.has_method("setup_event"):
		popup.setup_event(3) # EventType.SANCTUARY = 3
	popup.event_completed.connect(_on_event_completed.bind(popup))

func _on_event_completed(popup_instance):
	popup_instance.queue_free()
	handle_battle_end(true, false)

func handle_return_to_town():
	var map_manager = get_node_or_null("/root/MapManager")
	if map_manager:
		map_manager.set("should_generate_new_dungeon", false)
	
	current_battle_count = 0
	current_stage = 1
	is_additional_exploration_mode = false
	if scene_manager:
		scene_manager.go_to_town(true)

func update_player_node_stats():
	if player_node and player_node.has_method("update_stats_from_player_manager"):
		player_node.update_stats_from_player_manager(player_manager)

func start_dungeon_initial_sequence():
	current_game_phase = GamePhase.PREPARE
	if ui_manager and ui_manager.has_method("show_screen"):
		ui_manager.show_screen(1) # Screen.DESTINY_DESIGN = 1

func handle_additional_exploration():
	is_additional_exploration_mode = true
	var mm = get_node_or_null("/root/MapManager")
	if mm: mm.set("should_generate_new_dungeon", false)
	if scene_manager:
		scene_manager.start_dungeon(selected_dungeon_id, true)

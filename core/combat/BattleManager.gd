extends Node

# 다른 매니저 및 노드 참조
var player_node: CharacterBody2D # 순환 참조 방지를 위해 기본 노드 타입 사용
var enemies: Array[CharacterBody2D] = [] # 적 캐릭터 배열
var game_manager: Node 
var is_battle_active: bool = false
var hex_grid_manager: Node

func _ready():
	print("--- BattleManager.gd: 초기화 시작 ---")
	set_process(false)
	print("--- BattleManager.gd: 초기화 완료 ---")

func start_battle(p: CharacterBody2D, p_enemies: Array[CharacterBody2D], gm: Node):
	game_manager = gm
	player_node = p
	enemies = p_enemies
	is_battle_active = true
	
	if player_node:
		player_node.set("is_in_battle", true)
		player_node.set_process(true)
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set("is_in_battle", true)
			enemy.set_process(true)
	
	set_process(true)
	print("--- 전투 시작! 적 수: ", enemies.size(), " ---")
	
	_print_character_stats(player_node)
	for enemy in enemies:
		_print_character_stats(enemy)

func _process(_delta: float):
	if not is_battle_active: return
	
	if player_node and player_node.get("current_stats"):
		var stats = player_node.get("current_stats")
		if stats.has_method("get_stat"):
			var hp_stat = stats.get_stat("health")
			if hp_stat and hp_stat.get("current_value") <= 0:
				_handle_battle_end(false)
				return
		
	_update_auto_targeting()

	var all_enemies_dead = true
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.get("current_stats"):
			var stats = enemy.get("current_stats")
			if stats.has_method("get_stat"):
				var hp_stat = stats.get_stat("health")
				if hp_stat and hp_stat.get("current_value") > 0:
					all_enemies_dead = false
					break
			
	if all_enemies_dead:
		_handle_battle_end(true)

func _update_auto_targeting():
	if not is_instance_valid(player_node): return
	
	var current_target = player_node.get("target")
	var is_target_invalid = true
	
	if is_instance_valid(current_target) and current_target.get("current_stats"):
		var stats = current_target.get("current_stats")
		if stats.has_method("get_stat"):
			var hp_stat = stats.get_stat("health")
			if hp_stat and hp_stat.get("current_value") > 0:
				is_target_invalid = false
	
	if is_target_invalid:
		var next_target = null
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.get("current_stats"):
				var stats = enemy.get("current_stats")
				if stats.has_method("get_stat"):
					var hp_stat = stats.get_stat("health")
					if hp_stat and hp_stat.get("current_value") > 0:
						next_target = enemy
						break
		
		if next_target:
			set_player_target(next_target)
			print("BattleManager: Target automatically switched to ", next_target.name)

func _handle_battle_end(win: bool):
	if not is_battle_active: return
	is_battle_active = false
	
	set_process(false)

	if win and is_instance_valid(player_node):
		_apply_post_battle_recovery()

	if is_instance_valid(player_node):
		player_node.set_process(false)
		player_node.set("is_in_battle", false)
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.set("is_in_battle", false)
	
	enemies.clear()

	if game_manager and game_manager.has_method("handle_battle_end"):
		game_manager.handle_battle_end(win)

func _apply_post_battle_recovery():
	if not player_node or not player_node.get("current_stats"): return
	
	var stats = player_node.get("current_stats")
	if not stats.has_method("get_stat"): return
	
	var hp_stat = stats.get_stat("health")
	var recovery_stat = stats.get_stat("rec")
	
	if not hp_stat or not recovery_stat: return
	
	var max_hp = hp_stat.get("computed_value")
	var current_hp = hp_stat.get("current_value")
	var missing_hp = max_hp - current_hp
	
	if missing_hp <= 0: return
	
	var sm = get_node_or_null("/root/StatManager")
	if sm and sm.has_method("calculate_recovery_percentage"):
		var recovery_rate = sm.calculate_recovery_percentage(recovery_stat.get("computed_value"))
		var recovery_amount = int(missing_hp * recovery_rate)
		
		if recovery_amount > 0:
			hp_stat.set("current_value", min(max_hp, current_hp + recovery_amount))
			if player_node.has_method("update_hp_label"):
				player_node.update_hp_label()
			print("BattleManager: 전투 후 회복력(REC) 발동! +", recovery_amount, " HP 회복 (비율: ", recovery_rate * 100, "%)")

# GameManager 호출과 파라미터 타입 일치
func prepare_battle(node: Resource, p_player: CharacterBody2D, p_enemies: Array[CharacterBody2D], p_stage: int, p_battle_count: int, p_ui_manager: Node, p_stage_info_hud: Control):
	print("DEBUG: BattleManager: prepare_battle called.")
	enemies = p_enemies
	player_node = p_player

	if is_instance_valid(p_player): p_player.set("visible", true)
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not is_instance_valid(enemy): continue
		
		enemy.set("visible", true)
		enemy.set("grid_manager", hex_grid_manager)
		
		# [피드백 반영] 겹침 방지를 위한 빈 타일 찾기
		var spawn_x = 5 + (i % 2) # x = 5 또는 6
		var spawn_y = 1 + i # y = 1, 2, 3...
		if spawn_y > 4: spawn_y = 4 # 5행을 넘지 않도록
		var pos = Vector2i(spawn_x, spawn_y)
		
		if hex_grid_manager and hex_grid_manager.has_method("is_tile_occupied"):
			var attempts = 0
			while hex_grid_manager.is_tile_occupied(pos) and attempts < 15:
				spawn_y = (spawn_y + 1) % 5
				if spawn_y == 0: spawn_x = (spawn_x - 1) if spawn_x > 2 else 6
				pos = Vector2i(spawn_x, spawn_y)
				attempts += 1
				
		enemy.set("grid_pos", pos)
		
		var hp_multiplier = 1.0
		var is_boss = false
		if node:
			var node_type = node.get("node_type")
			match node_type:
				"elite":
					hp_multiplier = 1.5
				"boss":
					hp_multiplier = 2.0
					is_boss = true
		
		enemy.set("is_boss", is_boss)
		if enemies.size() > 1 and not is_boss:
			hp_multiplier *= 0.7 
			
		if enemy.has_method("set_level"):
			enemy.set_level(p_stage, p_battle_count, hp_multiplier)
		if enemy.has_method("reset_for_next_battle"): enemy.reset_for_next_battle()
		if enemy.has_method("reset_battle_state"): enemy.reset_battle_state()
		if enemy.has_method("update_hp_label"): enemy.update_hp_label()

	if enemies.size() > 0:
		set_player_target(enemies[0])

	if p_ui_manager and p_ui_manager.has_method("show_screen"):
		p_ui_manager.show_screen(2) # UIManager.Screen.BATTLE_HUD = 2
	
	if p_player and p_player.has_method("update_hp_label"):
		p_player.update_hp_label()

	if p_stage_info_hud:
		p_stage_info_hud.set("visible", true)

	if p_ui_manager and p_ui_manager.get("battle_hud"):
		var bh = p_ui_manager.get("battle_hud")
		if bh and bh.has_method("show_start_combat_button"):
			bh.show_start_combat_button()

func set_player_target(new_target: CharacterBody2D):
	if not is_instance_valid(player_node): return
	
	var current_target = player_node.get("target")
	if is_instance_valid(current_target) and current_target.has_method("set_selected"):
		current_target.set_selected(false)
	
	if is_instance_valid(new_target):
		player_node.set("target", new_target)
		if new_target.has_method("set_selected"):
			new_target.set_selected(true)
		print("BattleManager: Player target changed to ", new_target.name)
	else:
		player_node.set("target", null)
		print("BattleManager: Player target cleared.")

func set_player_stance(new_stance: int):
	if player_node and player_node.has_method("set_stance"):
		player_node.set_stance(new_stance)
	else:
		printerr("BattleManager: player_node가 유효하지 않아 스탠스를 설정할 수 없습니다.")

func _print_character_stats(char: CharacterBody2D):
	if not is_instance_valid(char) or not char.get("current_stats"):
		print("DEBUG: 캐릭터 또는 스탯 매니저가 유효하지 않습니다.")
		return

	print("DEBUG: 캐릭터: ", char.name)
	var stats = char.get("current_stats")
	if not stats.has_method("get_stat"): return
	
	var stat_keys = ["health", "atk", "vit", "agi", "spd", "res"]
	for key in stat_keys:
		var stat = stats.get_stat(key)
		if stat:
			print("DEBUG:   ", key, ": base=", stat.get("base_value"), ", current=", stat.get("current_value"), ", computed=", stat.get("computed_value"))
		else:
			print("DEBUG:   ", key, ": 스탯을 찾을 수 없습니다.")

extends Node # BattleManager는 Node 타입으로 생성되었습니다.

# 다른 매니저 및 노드 참조 (Main.gd에서 설정될 예정)
var player_node: Character # Player.tscn 인스턴스
var enemies: Array[Character] = [] # 적 캐릭터 배열
var game_manager: Node # GameManager 참조 (전투 종료 콜백용)
var is_battle_active: bool = false

func _ready():
	print("--- BattleManager.gd: 초기화 시작 ---")
	set_process(false)
	print("--- BattleManager.gd: 초기화 완료 ---
")

# 전투 시작 함수 (GameManager에서 호출)
func start_battle(p: Character, p_enemies: Array[Character], gm: Node):
	game_manager = gm
	player_node = p
	enemies = p_enemies
	is_battle_active = true
	
	player_node.is_in_battle = true
	player_node.set_process(true)
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.is_in_battle = true
			enemy.set_process(true)
			# 적 사망 시 타겟팅 목록에서 제거 등을 위해 시그널 연결 가능 (향후 확장)
	
	set_process(true)
	print("--- 전투 시작! 적 수: ", enemies.size(), " ---")
	
	_print_character_stats(player_node)
	for enemy in enemies:
		_print_character_stats(enemy)

# _process 함수는 전투가 진행 중일 때만 활성화됩니다.
func _process(_delta: float):
	if not is_battle_active: return
	
	# 플레이어 패배 확인
	if player_node.current_stats.get_stat("health").current_value <= 0:
		_handle_battle_end(false) # 패배
		return
		
	# --- 타겟 자동 전환 로직 ---
	_update_auto_targeting()

	# 모든 적 패배 확인
	var all_enemies_dead = true
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.current_stats.get_stat("health").current_value > 0:
			all_enemies_dead = false
			break
			
	if all_enemies_dead:
		_handle_battle_end(true) # 승리

## 플레이어의 타겟이 사망했을 때 살아있는 다른 적을 자동으로 선택
func _update_auto_targeting():
	if not is_instance_valid(player_node): return
	
	var current_target = player_node.target
	var is_target_invalid = not is_instance_valid(current_target) or current_target.current_stats.get_stat("health").current_value <= 0
	
	if is_target_invalid:
		# 살아있는 적 찾기
		var next_target = null
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.current_stats.get_stat("health").current_value > 0:
				next_target = enemy
				break
		
		if next_target:
			set_player_target(next_target)
			print("BattleManager: Target automatically switched to ", next_target.name)

# 전투 종료 처리 함수 (GameManager에 결과 전달)
func _handle_battle_end(win: bool):
	if not is_battle_active: return
	is_battle_active = false
	
	set_process(false)

	# 승리 시 회복력(Recovery) 기반 자동 회복 처리
	if win and is_instance_valid(player_node):
		_apply_post_battle_recovery()

	player_node.set_process(false)
	player_node.is_in_battle = false
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_process(false)
			enemy.is_in_battle = false
	
	# [신규] 적 리스트 참조 해제 (GameManager에서 queue_free() 시 안전성 확보)
	enemies.clear()

	if game_manager:
		game_manager.handle_battle_end(win)

func _apply_post_battle_recovery():
	var stats = player_node.current_stats
	var hp_stat = stats.get_stat("health")
	var recovery_stat = stats.get_stat("rec")
	
	if not hp_stat or not recovery_stat: return
	
	var max_hp = hp_stat.computed_value
	var current_hp = hp_stat.current_value
	var missing_hp = max_hp - current_hp
	
	if missing_hp <= 0: return
	
	# StatManager를 통한 회복 비율 계산 (Recovery Power 수치 기반)
	var recovery_rate = StatManager.calculate_recovery_percentage(recovery_stat.computed_value)
	var recovery_amount = int(missing_hp * recovery_rate)
	
	if recovery_amount > 0:
		hp_stat.current_value = min(max_hp, current_hp + recovery_amount)
		player_node.update_hp_label()
		print("BattleManager: 전투 후 회복력(REC) 발동! +", recovery_amount, " HP 회복 (비율: ", recovery_rate * 100, "%)")

func prepare_battle(node: DungeonNode, p_player: Character, p_enemies: Array[Character], p_stage: int, p_battle_count: int, p_ui_manager: UIManager, p_stage_info_hud: Control):
# ... (기존 코드 유지) ...

	print("DEBUG: BattleManager: prepare_battle called.")
	enemies = p_enemies
	player_node = p_player # player_node 저장 확인

	if is_instance_valid(p_player): p_player.visible = true
	
	# 적들 배치 및 초기화
	var spacing = 150.0
	var start_x = 800.0
	var start_y = 300.0
	
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not is_instance_valid(enemy): continue
		
		enemy.visible = true
		# 적 위치 분산 (복수 출현 대응)
		var offset_y = (i - (enemies.size() - 1) / 2.0) * spacing
		enemy.position = Vector2(start_x, start_y + offset_y)
		
		var hp_multiplier = 1.0
		var is_boss = false
		if node:
			match node.node_type:
				"elite":
					hp_multiplier = 1.5
				"boss":
					hp_multiplier = 2.0
					is_boss = true
		
		enemy.is_boss = is_boss
		# 쫄몹(미니언)인 경우 HP 패널티 (적 수가 많을 때 밸런스 조정용)
		if enemies.size() > 1 and not is_boss:
			hp_multiplier *= 0.7 
			
		enemy.set_level(p_stage, p_battle_count, hp_multiplier)
		if enemy.has_method("reset_for_next_battle"): enemy.reset_for_next_battle()
		if enemy.has_method("reset_battle_state"): enemy.reset_battle_state() # [신규]
		enemy.update_hp_label()

	# 기본 타겟 설정 (첫 번째 적)
	if enemies.size() > 0:
		set_player_target(enemies[0])

	# Update UI
	if p_ui_manager:
		p_ui_manager.show_screen(UIManager.Screen.BATTLE_HUD)
	
	p_player.update_hp_label()

	if p_stage_info_hud:
		p_stage_info_hud.show()

	if p_ui_manager and p_ui_manager.battle_hud:
		p_ui_manager.battle_hud.show_start_combat_button()

## 플레이어의 공격 대상 수동 설정
func set_player_target(new_target: Character):
	if not is_instance_valid(player_node): return
	
	# 기존 타겟 선택 해제
	if player_node.target and player_node.target.has_method("set_selected"):
		player_node.target.set_selected(false)
	
	# 새 타겟 설정
	player_node.target = new_target
	if new_target and new_target.has_method("set_selected"):
		new_target.set_selected(true)
	
	print("BattleManager: Player target changed to ", new_target.name)


func set_player_stance(new_stance: Character.Stance):
	if player_node:
		player_node.set_stance(new_stance)
	else:
		printerr("BattleManager: player_node가 유효하지 않아 스탠스를 설정할 수 없습니다.")

func _print_character_stats(char: Character):
	if not is_instance_valid(char) or not char.current_stats:
		print("DEBUG: 캐릭터 또는 스탯 매니저가 유효하지 않습니다.")
		return

	print("DEBUG: 캐릭터: ", char.name)
	var stats = char.current_stats
	
	var stat_keys = ["health", "atk", "vit", "agi", "spd", "res"] # 주요 스탯 출력
	for key in stat_keys:
		var stat = stats.get_stat(key)
		if stat:
			print("DEBUG:   ", key, ": base=", stat.base_value, ", current=", stat.current_value, ", computed=", stat.computed_value)
		else:
			print("DEBUG:   ", key, ": 스탯을 찾을 수 없습니다.")

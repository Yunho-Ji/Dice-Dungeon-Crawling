extends Node # BattleManager는 Node 타입으로 생성되었습니다.

# 다른 매니저 및 노드 참조 (Main.gd에서 설정될 예정)
var player_node: Character # Player.tscn 인스턴스
var enemy_node: Character  # Enemy.tscn 인스턴스
var game_manager: Node # GameManager 참조 (전투 종료 콜백용)
var is_battle_active: bool = false

func _ready():
	print("--- BattleManager.gd: 초기화 시작 ---")
	# _ready()는 Main.gd에서 add_child될 때 호출됩니다.
	# 초기에는 _process()를 비활성화합니다.
	set_process(false)
	print("--- BattleManager.gd: 초기화 완료 ---
")

# 전투 시작 함수 (GameManager에서 호출)
func start_battle(p: Character, e: Character, gm: Node):
	game_manager = gm
	player_node = p
	enemy_node = e
	is_battle_active = true
	player_node.is_in_battle = true
	enemy_node.is_in_battle = true
	player_node.set_process(true)
	enemy_node.set_process(true)
	set_process(true)
	print("--- 전투 시작!---")
	
	# DEBUG: 전투 시작 시 플레이어 스탯
	print("DEBUG: --- 전투 시작: 플레이어 스탯 ---")
	_print_character_stats(player_node)
	
	# DEBUG: 전투 시작 시 적 스탯
	print("DEBUG: --- 전투 시작: 적 스탯 ---")
	_print_character_stats(enemy_node)

# _process 함수는 전투가 진행 중일 때만 활성화됩니다.
func _process(_delta: float):
	# 게임 종료 조건 확인
	if player_node.current_stats.get_stat("health").current_value <= 0:
		_handle_battle_end(false) # 패배
	elif enemy_node.current_stats.get_stat("health").current_value <= 0:
		_handle_battle_end(true) # 승리

# 전투 종료 처리 함수 (GameManager에 결과 전달)
func _handle_battle_end(win: bool):
	if not is_battle_active: return
	is_battle_active = false
	
	# DEBUG: 전투 종료 시 플레이어 스탯
	print("DEBUG: --- 전투 종료: 플레이어 스탯 ---")
	_print_character_stats(player_node)
	
	# DEBUG: 전투 종료 시 적 스탯
	print("DEBUG: --- 전투 종료: 적 스탯 ---")
	_print_character_stats(enemy_node)
	
	# BattleManager 자신의 _process() 함수 비활성화
	set_process(false)

	# 플레이어와 적의 _process() 함수 비활성화 (전투 종료)
	player_node.set_process(false)
	enemy_node.set_process(false)
	player_node.is_in_battle = false
	enemy_node.is_in_battle = false

	# GameManager에 전투 결과 전달
	if game_manager:
		game_manager.handle_battle_end(win)
	else:
		print("오류: GameManager 참조가 설정되지 않았습니다.")

func prepare_battle(node: DungeonNode, p_player: Character, p_enemy: Character, p_stage: int, p_battle_count: int, p_ui_manager: UIManager, p_stage_info_hud: Control):
	print("DEBUG: BattleManager: prepare_battle called.")

	# Make sure characters are visible for the battle
	if is_instance_valid(p_player): p_player.visible = true
	if is_instance_valid(p_enemy): p_enemy.visible = true

	# Set enemy level based on node type
	var hp_multiplier = 1.0
	var is_boss = false
	if node:
		match node.node_type:
			"elite":
				hp_multiplier = 1.5
				print("엘리트 전투 준비!")
			"boss":
				hp_multiplier = 2.0
				is_boss = true
				print("보스 전투 준비!")
	
	p_enemy.is_boss = is_boss # Correctly set the enemy's is_boss property
	p_enemy.set_level(p_stage, p_battle_count, hp_multiplier)
	p_enemy.position = Vector2(800, 300)
	print("DEBUG: BattleManager: Enemy stats set: HP:", p_enemy.current_stats.get_stat("health").computed_value)

	# Reset characters
	# if p_player.has_method("reset_for_next_battle"): p_player.reset_for_next_battle()
	if p_enemy.has_method("reset_for_next_battle"): p_enemy.reset_for_next_battle()

	# Update UI
	if p_ui_manager:
		p_ui_manager.show_screen(UIManager.Screen.BATTLE_HUD)
	
	p_player.update_hp_label()
	p_enemy.update_hp_label()

	if p_stage_info_hud:
		p_stage_info_hud.show()

	# Show the button to manually start combat
	if p_ui_manager and p_ui_manager.battle_hud:
		p_ui_manager.battle_hud.show_start_combat_button()

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
	if not stats:
		print("DEBUG: 스탯이 로드되지 않았습니다.")
		return

	var stat_keys = ["health", "attack_power", "defense"] # 주요 스탯만 출력
	for key in stat_keys:
		var stat = stats.get_stat(key)
		if stat:
			print("DEBUG:   ", key, ": base=", stat.base_value, ", current=", stat.current_value, ", computed=", stat.computed_value)
		else:
			print("DEBUG:   ", key, ": 스탯을 찾을 수 없습니다.")

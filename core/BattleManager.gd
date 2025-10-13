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
	print("--- BattleManager.gd: 초기화 완료 ---\n")

# 전투 시작 함수 (GameManager에서 호출)
func start_battle(p: Character, e: Character):
	player_node = p
	enemy_node = e
	is_battle_active = true
	player_node.is_in_battle = true
	enemy_node.is_in_battle = true
	player_node.set_process(true)
	enemy_node.set_process(true)
	set_process(true)
	print("--- 전투 시작! ---")

# _process 함수는 전투가 진행 중일 때만 활성화됩니다.
func _process(_delta: float):
	# 게임 종료 조건 확인
	if player_node.current_hp <= 0:
		_handle_battle_end(false) # 패배
	elif enemy_node.current_hp <= 0:
		_handle_battle_end(true) # 승리

# 전투 종료 처리 함수 (GameManager에 결과 전달)
func _handle_battle_end(win: bool):
	if not is_battle_active: return
	is_battle_active = false
	
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

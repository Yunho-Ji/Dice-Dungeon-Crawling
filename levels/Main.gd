extends Node2D

# 매니저 인스턴스 변수
var battle_manager: Node
var global_game_manager_instance: GameManager

var ui_manager_node: UIManager # UIManager 참조 추가

func _ready():
	print("--- Main.gd: 게임 초기화 시작 ---")
	randomize() # 난수 생성기 초기화
	global_game_manager_instance = get_node("/root/GameManager")
	
	battle_manager = Node.new()
	battle_manager.name = "BattleManager"
	add_child(battle_manager)

	# 2. 각 매니저에 스크립트 연결 (동적으로 스크립트 로드)
	battle_manager.set_script(load("res://core/BattleManager.gd"))

	# 3. 매니저 간 참조 설정
	# UIManager 노드를 Main 씬에서 직접 참조
	ui_manager_node = $UIManager as UIManager # Main 씬의 자식으로 UIManager가 있다고 가정

	battle_manager.game_manager = global_game_manager_instance # BattleManager refers to the autoloaded GameManager

	# 게임 시작 로직 호출 (GameManager에서 시작)
	call_deferred("start_game_deferred", global_game_manager_instance, battle_manager, ui_manager_node)

	print("--- Main.gd: 게임 초기화 완료 ---\n")


func start_game_deferred(game_manager_instance: GameManager, battle_mgr: Node, ui_mgr: UIManager):
	var player_node = null
	var enemy_node = null

	# Instantiate player based on selection
	var player_scene_path = ""
	if game_manager_instance.selected_player_type == "novice":
		player_scene_path = "res://characters/player/novice/Novice.tscn"
	elif game_manager_instance.selected_player_type == "archer":
		player_scene_path = "res://characters/player/archer/Archer.tscn"
	else:
		player_scene_path = "res://characters/player/novice/Novice.tscn" # Default fallback

	var player_scene = load(player_scene_path)
	player_node = player_scene.instantiate()
	player_node.name = "Player" # Ensure name is "Player" for other references
	add_child(player_node) # Add player to the scene

	for child in get_children():
		# Skip the newly added player_node if it's found again
		if child == player_node:
			continue
		if child.name == "Enemy":
			enemy_node = child

	assert(player_node != null, "Player 노드를 찾을 수 없습니다! (인스턴스화 실패)")
	assert(enemy_node != null, "Enemy 노드를 찾을 수 없습니다! (자식 순회)")
	game_manager_instance.initialize_game_scene(player_node, enemy_node, battle_mgr, dice_mgr, ui_mgr)

	# Retrieve and print selected dungeon ID
	var selected_dungeon_id = game_manager_instance.selected_dungeon_id
	if selected_dungeon_id != 0: # 0 is default, meaning no dungeon selected yet
		print("--- Main.gd: 선택된 던전 ID:", selected_dungeon_id, " ---")

	

	print("--- Main.gd: 게임 시작 지연 호출 완료 ---\n")


# Main.gd는 이제 _process()를 직접 관리하지 않습니다.
# 각 매니저가 자신의 _process()를 관리합니다.

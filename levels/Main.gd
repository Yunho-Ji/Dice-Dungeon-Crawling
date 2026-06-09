extends Node2D

# =============================================================================
# 노드 참조 (Node References)
# =============================================================================
@onready var battle_manager: Node = $BattleManager
@onready var ui_manager: UIManager = $UIManager
@onready var stage_info_hud_instance: Control = $UIManager/StageInfoHUD
@onready var status_popup_instance: PanelContainer = $StatusPopup
@onready var enemy_node = $Enemy
@onready var hex_grid_manager: Node = $HexGridManager # [v7.4 신규]

@export var novice_player_scene: PackedScene
@export var archer_player_scene: PackedScene

# --- 싱글톤 ---
@onready var game_manager: Node = get_node("/root/GameManager")
@onready var scene_manager: Node = get_node("/root/SceneManager")
@onready var player_manager: Node = get_node("/root/PlayerManager")

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	print("--- Main.gd: 게임 초기화 시작 ---")
	randomize()
	
	if battle_manager:
		battle_manager.game_manager = game_manager
		battle_manager.hex_grid_manager = hex_grid_manager # 그리드 매니저 연결

	# StatusPopup이 보이지 않도록 시작 시 숨깁니다.
	if status_popup_instance:
		status_popup_instance.hide()

	call_deferred("start_game_deferred")

	print("--- Main.gd: 게임 초기화 완료 ---")

# call_deferred를 통해 호출되는, 지연된 게임 시작 함수입니다.
func start_game_deferred():
	print("DEBUG: Main.gd: start_game_deferred called.")
	print("DEBUG: Main.gd: game_manager valid: ", is_instance_valid(game_manager))
	var player_node = null

	# --- 플레이어 생성 및 스탯 설정 (v7.4 데이터 중심 리팩토링) ---
	var player_scene: PackedScene = player_manager.player_data.character_scene
	
	if not player_scene:
		# 레거시 호환 및 방어적 코드
		if player_manager.player_data.character_name == "Novice":
			player_scene = novice_player_scene
		else:
			player_scene = archer_player_scene

	player_node = player_scene.instantiate()
	player_node.name = "Player"
	player_node.set("grid_manager", hex_grid_manager) # [수정] 안전한 속성 주입
	add_child(player_node)
	
	# 초기 위치 설정 (안전 구역 중앙)
	player_node.grid_pos = Vector2i(7, 8) 
	
	print("DEBUG: Main.gd: Player node added. Is player_node valid: ", is_instance_valid(player_node))


	# --- 최종 초기화 ---
	assert(player_node != null, "Player 노드를 찾을 수 없습니다!")
	assert(enemy_node != null, "Enemy 노드를 찾을 수 없습니다!")
	
	game_manager.initialize_game_scene(player_node, enemy_node, battle_manager, ui_manager, stage_info_hud_instance, scene_manager, player_manager)

	# 던전 생성 및 초기 시퀀스 결정
	var map_manager = get_node("/root/MapManager")
	var was_new_dungeon = map_manager.should_generate_new_dungeon
	map_manager.generate_dungeon_if_needed()
	
	# [신규] 던전 진입 시 현재 노드(시작 노드)를 GameManager에 알림
	var current_node_id = map_manager.player_run_state.CurrentNodeID
	if map_manager.dungeon_data.has("nodes") and map_manager.dungeon_data.nodes.has(current_node_id):
		var start_node = map_manager.dungeon_data.nodes[current_node_id]
		game_manager.prepare_dungeon_battle(start_node)
	
	if was_new_dungeon:
		game_manager.start_dungeon_initial_sequence()
	else:
		map_manager.show_dungeon_map()

	print("--- Main.gd: 게임 시작 지연 호출 완료 ---")

func _input(event):
	# [피드백 반영] 'G' 키나 'Tab' 키로 그리드 가시성 토글
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G or event.keycode == KEY_TAB:
			if is_instance_valid(hex_grid_manager) and hex_grid_manager.has_method("toggle_grid_visibility"):
				hex_grid_manager.toggle_grid_visibility()
				
	# [v7.4 이식] 배치 페이즈이거나 전투 중이 아닐 때만 타일 클릭 허용
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(hex_grid_manager) and is_instance_valid(game_manager):
				# 전투가 아직 시작되지 않았을 때만 위치 변경 가능 (배치 페이즈)
				if game_manager.battle_manager and not game_manager.battle_manager.is_battle_active:
					var player_node = game_manager.player_node
					if is_instance_valid(player_node):
						var map_pos = hex_grid_manager.local_to_map(get_local_mouse_position())
						if player_node.place_at(map_pos):
							print("DEBUG: Main: 플레이어 배치 이동 -> ", map_pos)

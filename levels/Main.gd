extends Node2D

# =============================================================================
# 노드 참조 (Node References)
# =============================================================================
@onready var battle_manager: Node = $BattleManager
@onready var ui_manager: UIManager = $UIManager
@onready var stage_info_hud_instance: Control = $UIManager/StageInfoHUD
@onready var status_popup_instance: PanelContainer = $StatusPopup
@onready var enemy_node = $Enemy

@export var novice_player_scene: PackedScene
@export var archer_player_scene: PackedScene

# --- 싱글톤 ---
@onready var game_manager: GameManager = get_node("/root/GameManager")
@onready var scene_manager: SceneManager = get_node("/root/SceneManager")
@onready var player_manager: PlayerManager = get_node("/root/PlayerManager")

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	print("--- Main.gd: 게임 초기화 시작 ---")
	randomize()
	
	if battle_manager:
		battle_manager.game_manager = game_manager

	# StatusPopup이 보이지 않도록 시작 시 숨깁니다.
	if status_popup_instance:
		status_popup_instance.hide()

	call_deferred("start_game_deferred")

	print("--- Main.gd: 게임 초기화 완료 ---\
")

# call_deferred를 통해 호출되는, 지연된 게임 시작 함수입니다.
func start_game_deferred():
	print("DEBUG: Main.gd: start_game_deferred called.")
	print("DEBUG: Main.gd: game_manager valid: ", is_instance_valid(game_manager)) # New line
	var player_node = null

	# --- 플레이어 생성 및 스탯 설정 ---
	var player_scene: PackedScene
	if player_manager.player_data.character_name == "Novice":
		player_scene = novice_player_scene
	else:
		player_scene = archer_player_scene

	player_node = player_scene.instantiate()
	player_node.name = "Player"
	add_child(player_node)
	print("DEBUG: Main.gd: Player node added. Is player_node valid: ", is_instance_valid(player_node)) # New line
	print("DEBUG: Main.gd: Player node _ready() called: ", player_node.is_node_ready()) # New line


	# --- 최종 초기화 ---
	assert(player_node != null, "Player 노드를 찾을 수 없습니다!")
	assert(enemy_node != null, "Enemy 노드를 찾을 수 없습니다!")
	
	# [수정] Character.gd 내부에서 자체적으로 입력을 처리하므로 Main.gd에서의 중복 연결 제거
	# player_node.input_event.connect(Callable(self, "_on_character_input_event").bind(player_node))

	print("DEBUG: Main.gd: Calling game_manager.initialize_game_scene with:") # New line
	print("DEBUG:   player_node valid: ", is_instance_valid(player_node)) # New line
	print("DEBUG:   enemy_node valid: ", is_instance_valid(enemy_node)) # New line
	print("DEBUG:   battle_manager valid: ", is_instance_valid(battle_manager)) # New line
	print("DEBUG:   ui_manager valid: ", is_instance_valid(ui_manager)) # New line
	print("DEBUG:   stage_info_hud_instance valid: ", is_instance_valid(stage_info_hud_instance)) # New line
	print("DEBUG:   scene_manager valid: ", is_instance_valid(scene_manager)) # New line
	print("DEBUG:   player_manager valid: ", is_instance_valid(player_manager)) # New line
	game_manager.initialize_game_scene(player_node, enemy_node, battle_manager, ui_manager, stage_info_hud_instance, scene_manager, player_manager)

	# 던전 생성 및 초기 시퀀스 결정
	var map_manager = get_node("/root/MapManager")
	var was_new_dungeon = map_manager.should_generate_new_dungeon
	map_manager.generate_dungeon_if_needed()
	
	if was_new_dungeon:
		# 새 던전이면 운명 설계부터 시작
		game_manager.start_dungeon_initial_sequence()
	else:
		# 이미 진행 중인 던전(추가 탐험 등)이면 지도 표시
		map_manager.show_dungeon_map()

	print("--- Main.gd: 게임 시작 지연 호출 완료 ---")

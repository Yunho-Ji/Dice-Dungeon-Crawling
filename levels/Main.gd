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
	if player_manager.selected_player_type == "novice":
		player_scene = novice_player_scene
	else:
		player_scene = archer_player_scene

	player_node = player_scene.instantiate()
	player_node.name = "Player"
	add_child(player_node)
	print("DEBUG: Main.gd: Player node added. Is player_node valid: ", is_instance_valid(player_node)) # New line
	print("DEBUG: Main.gd: Player node _ready() called: ", player_node.is_node_ready()) # New line

	var player_class = player_manager.selected_player_type
	var stats = player_manager.get_class_stats(player_class)
	if not stats.is_empty():
		player_node.set_stat("max_hp", stats.max_hp)
		player_node.set_stat("current_hp", stats.max_hp) # current_hp should be set to max_hp initially
		player_node.set_stat("attack_power", stats.attack_power)
		player_node.set_stat("defense", stats.defense)
		player_node.set_stat("attack_speed", stats.attack_speed)
	print("DEBUG: Main.gd: Player stats set. HP:", player_node.get_stat("max_hp"), ", ATK:", player_node.get_stat("attack_power")) # New line

	# --- 최종 초기화 ---
	assert(player_node != null, "Player 노드를 찾을 수 없습니다!")
	assert(enemy_node != null, "Enemy 노드를 찾을 수 없습니다!")
	
	player_node.input_event.connect(Callable(self, "_on_character_input_event").bind(player_node))
	enemy_node.input_event.connect(Callable(self, "_on_character_input_event").bind(enemy_node))

	print("DEBUG: Main.gd: Calling game_manager.initialize_game_scene with:") # New line
	print("DEBUG:   player_node valid: ", is_instance_valid(player_node)) # New line
	print("DEBUG:   enemy_node valid: ", is_instance_valid(enemy_node)) # New line
	print("DEBUG:   battle_manager valid: ", is_instance_valid(battle_manager)) # New line
	print("DEBUG:   ui_manager valid: ", is_instance_valid(ui_manager)) # New line
	print("DEBUG:   stage_info_hud_instance valid: ", is_instance_valid(stage_info_hud_instance)) # New line
	print("DEBUG:   scene_manager valid: ", is_instance_valid(scene_manager)) # New line
	print("DEBUG:   player_manager valid: ", is_instance_valid(player_manager)) # New line
	game_manager.initialize_game_scene(player_node, enemy_node, battle_manager, ui_manager, stage_info_hud_instance, scene_manager, player_manager)

	print("--- Main.gd: 게임 시작 지연 호출 완료 ---\
")

func _on_character_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, character: Character):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if status_popup_instance:
			status_popup_instance.show_stats(character)
			# 팝업을 중앙에 배치하는 대신, 현재 위치에 그대로 표시합니다.
			pass

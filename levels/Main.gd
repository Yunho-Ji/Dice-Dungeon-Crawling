extends Node2D

# =============================================================================
# 노드 참조 (Node References)
# =============================================================================
@onready var battle_manager: Node = $BattleManager
@onready var ui_manager: UIManager = $UIManager
@onready var stage_info_hud_instance: Control = $UIManager/StageInfoHUD
@onready var status_popup_instance: PanelContainer = $StatusPopup
@onready var enemy_node = $Enemy

# --- 싱글톤 ---
@onready var game_manager: GameManager = get_node("/root/GameManager")

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
	var player_node = null

	# --- 플레이어 생성 및 스탯 설정 ---
	var player_scene_path = ""
	if game_manager.selected_player_type == "novice":
		player_scene_path = "res://characters/player/novice/Novice.tscn"
	else:
		player_scene_path = "res://characters/player/archer/Archer.tscn"

	var player_scene = load(player_scene_path)
	player_node = player_scene.instantiate()
	player_node.name = "Player"
	add_child(player_node)

	var player_class = game_manager.selected_player_type
	if game_manager.CLASS_STATS.has(player_class):
		var stats = game_manager.CLASS_STATS[player_class]
		player_node.set_max_hp(stats.max_hp)
		player_node.set_current_hp(stats.max_hp)
		player_node.set_attack_power(stats.attack_power)
		player_node.set_defense(stats.defense)
		player_node.set_attack_speed(stats.attack_speed)

	# --- 최종 초기화 ---
	assert(player_node != null, "Player 노드를 찾을 수 없습니다!")
	assert(enemy_node != null, "Enemy 노드를 찾을 수 없습니다!")
	
	player_node.input_event.connect(Callable(self, "_on_character_input_event").bind(player_node))
	enemy_node.input_event.connect(Callable(self, "_on_character_input_event").bind(enemy_node))

	game_manager.initialize_game_scene(player_node, enemy_node, battle_manager, ui_manager, stage_info_hud_instance)

	print("--- Main.gd: 게임 시작 지연 호출 완료 ---\
")

func _on_character_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, character: Character):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if status_popup_instance:
			status_popup_instance.show_stats(character)
			# 팝업을 중앙에 배치하는 대신, 현재 위치에 그대로 표시합니다.
			pass

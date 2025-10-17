# UIManager.gd
class_name UIManager
extends CanvasLayer

enum Screen { NONE, DESTINY_DESIGN, BATTLE_HUD, INVENTORY }

@export var destiny_design_screen_scene: PackedScene
@export var inventory_screen_scene: PackedScene
@export var advantage_label_scene: PackedScene

@onready var advantage_container = $AdvantageContainer
@onready var battle_hud = $BattleHUD
@onready var game_manager: GameManager = get_node("/root/GameManager") as GameManager

var screen_nodes: Dictionary = {}
var current_screen: Screen = Screen.NONE

func _ready():
	screen_nodes[Screen.BATTLE_HUD] = battle_hud
	
	# BattleHUD 시그널 연결
	battle_hud.inventory_opened.connect(_on_inventory_opened)
	battle_hud.destiny_design_opened.connect(_on_destiny_design_opened)
	battle_hud.next_battle_requested.connect(game_manager.handle_start_combat) # '다음 전투' 요청을 GameManager에 바로 연결
	
	# GameManager 시그널 연결
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	
	# 전투 관련 시그널을 GameManager에 직접 연결
	battle_hud.attack_stance_selected.connect(game_manager.handle_attack_stance)
	battle_hud.defense_stance_selected.connect(game_manager.handle_defense_stance)
	battle_hud.dodge_stance_selected.connect(game_manager.handle_dodge_stance)
	battle_hud.skill_1_used.connect(game_manager.use_skill_1)
	battle_hud.skill_2_used.connect(game_manager.use_skill_2)

	for screen_key in screen_nodes:
		if screen_key != Screen.BATTLE_HUD:
			screen_nodes[screen_key].visible = false

func show_screen(screen_type: Screen):
	if screen_type == Screen.DESTINY_DESIGN or screen_type == Screen.INVENTORY:
		pass
	else:
		if current_screen != Screen.NONE and screen_nodes.has(current_screen):
			screen_nodes[current_screen].visible = false

	current_screen = screen_type
	if not screen_nodes.has(screen_type):
		var new_screen_instance = null
		match screen_type:
			Screen.DESTINY_DESIGN:
				new_screen_instance = destiny_design_screen_scene.instantiate()
				new_screen_instance.connect("tree_exited", func(): screen_nodes.erase(Screen.DESTINY_DESIGN))
				if game_manager.has_method("handle_dice_roll_request"):
					new_screen_instance.dice_roll_requested.connect(game_manager.handle_dice_roll_request)
				else:
					printerr("UIManager: GameManager does not have handle_dice_roll_request method!")
			Screen.INVENTORY:
				new_screen_instance = inventory_screen_scene.instantiate()
				new_screen_instance.inventory_closed.connect(_on_inventory_closed)
				new_screen_instance.connect("tree_exited", func(): screen_nodes.erase(Screen.INVENTORY))
			_:
				printerr("UIManager: 동적으로 생성할 수 없는 화면입니다: ", screen_type)
				return
		
		if new_screen_instance:
			add_child(new_screen_instance)
			screen_nodes[screen_type] = new_screen_instance

	if screen_nodes.has(screen_type):
		screen_nodes[screen_type].visible = true

# --- GameManager 시그널 핸들러 ---
func _on_battle_started():
	battle_hud.set_destiny_button_enabled(false)
	battle_hud.set_next_battle_button_visible(false)

func _on_battle_ended(win: bool):
	if win:
		battle_hud.set_destiny_button_enabled(true)
		battle_hud.set_next_battle_button_visible(true)
	else: # 패배 시
		battle_hud.set_destiny_button_enabled(false)
		battle_hud.set_next_battle_button_visible(false)

# --- BattleHUD 시그널 핸들러 ---
func _on_inventory_opened():
	show_screen(Screen.INVENTORY)

func _on_inventory_closed():
	if screen_nodes.has(Screen.INVENTORY):
		screen_nodes[Screen.INVENTORY].queue_free()

func _on_destiny_design_opened():
	show_screen(Screen.DESTINY_DESIGN)

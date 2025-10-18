# UIManager.gd
class_name UIManager
extends CanvasLayer

enum Screen { NONE, DESTINY_DESIGN, BATTLE_HUD, INVENTORY, DUNGEON_MAP, END_OF_DUNGEON_OPTIONS }

@export var destiny_design_screen_scene: PackedScene
@export var inventory_screen_scene: PackedScene
@export var end_of_dungeon_screen_scene: PackedScene # New export for the end of dungeon screen
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
	battle_hud.map_requested.connect(get_node("/root/MapManager").show_dungeon_map)
	battle_hud.start_combat_requested.connect(game_manager.handle_start_combat)
	
	# GameManager 시그널 연결
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	
	# 전투 관련 시그널을 GameManager에 직접 연결
	battle_hud.attack_stance_selected.connect(game_manager.handle_attack_stance)
	battle_hud.defense_stance_selected.connect(game_manager.handle_defense_stance)
	battle_hud.dodge_stance_selected.connect(game_manager.handle_dodge_stance)
	battle_hud.skill_1_used.connect(game_manager.use_skill_1)
	battle_hud.skill_2_used.connect(game_manager.use_skill_2)

	show_screen(Screen.BATTLE_HUD) # Start with battle hud

func show_screen(screen_type: Screen, instance: Node = null):
	# Hide the current screen
	if current_screen != Screen.NONE and screen_nodes.has(current_screen):
		var current_screen_node = screen_nodes[current_screen]
		current_screen_node.visible = false
		# If the screen we are leaving is a temporary one (like the map), remove it
		if current_screen == Screen.DUNGEON_MAP or current_screen == Screen.INVENTORY or current_screen == Screen.DESTINY_DESIGN or current_screen == Screen.END_OF_DUNGEON_OPTIONS:
			current_screen_node.queue_free()
			screen_nodes.erase(current_screen)

	current_screen = screen_type

	# Show the new screen
	if not screen_nodes.has(screen_type):
		var new_screen_instance = instance # Use passed instance if available
		if not new_screen_instance:
			# Dynamically create instance if not passed
			match screen_type:
				Screen.DESTINY_DESIGN:
					new_screen_instance = destiny_design_screen_scene.instantiate()
					# Connect a new 'closed' signal to handle returning to the battle HUD
					new_screen_instance.closed.connect(_on_destiny_design_closed)
					if game_manager.has_method("handle_dice_roll_request"):
						new_screen_instance.dice_roll_requested.connect(game_manager.handle_dice_roll_request)
				Screen.INVENTORY:
					new_screen_instance = inventory_screen_scene.instantiate()
					new_screen_instance.inventory_closed.connect(_on_inventory_closed)
				Screen.END_OF_DUNGEON_OPTIONS:
					new_screen_instance = end_of_dungeon_screen_scene.instantiate()
					new_screen_instance.return_to_town_requested.connect(game_manager.handle_return_to_town)
					new_screen_instance.additional_exploration_requested.connect(game_manager.handle_additional_exploration)
				Screen.BATTLE_HUD:
					# Battle HUD is pre-loaded, do nothing
					pass
				_:
					printerr("UIManager: Cannot dynamically create screen: ", screen_type)
					return

		if new_screen_instance:
			add_child(new_screen_instance)
			screen_nodes[screen_type] = new_screen_instance

	if screen_nodes.has(screen_type):
		screen_nodes[screen_type].visible = true

func show_end_of_dungeon_options():
	show_screen(Screen.END_OF_DUNGEON_OPTIONS)

# --- GameManager 시그널 핸들러 ---
func _on_battle_started():
	battle_hud.set_destiny_button_enabled(false)
	# Hide both buttons when combat starts
	if battle_hud.map_button: battle_hud.map_button.visible = false
	if battle_hud.start_combat_button: battle_hud.start_combat_button.visible = false

func _on_battle_ended(win: bool):
	if win:
		battle_hud.set_destiny_button_enabled(true)
		battle_hud.show_map_button()
	else: # 패배 시
		battle_hud.set_destiny_button_enabled(false)

# --- BattleHUD 시그널 핸들러 ---
func _on_inventory_opened():
	show_screen(Screen.INVENTORY)

func _on_inventory_closed():
	show_screen(Screen.BATTLE_HUD)

func _on_destiny_design_opened():
	show_screen(Screen.DESTINY_DESIGN)

func _on_destiny_design_closed():
	show_screen(Screen.BATTLE_HUD)

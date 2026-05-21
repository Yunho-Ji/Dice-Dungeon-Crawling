# UIManager.gd
class_name UIManager
extends CanvasLayer

enum Screen { NONE, DESTINY_DESIGN, BATTLE_HUD, INVENTORY, DUNGEON_MAP, END_OF_DUNGEON_OPTIONS, LOOT_OFFER }

@export var destiny_design_screen_scene: PackedScene
@export var inventory_screen_scene: PackedScene
@export var end_of_dungeon_screen_scene: PackedScene
@export var loot_offer_screen_scene: PackedScene
@export var advantage_label_scene: PackedScene

@onready var advantage_container = get_node_or_null("AdvantageContainer")
@onready var battle_hud = get_node_or_null("BattleHUD")
@onready var game_manager: GameManager = get_node("/root/GameManager") as GameManager

const STATUS_POPUP_SCENE = preload("res://ui/StatusPopup.tscn")
var status_popup: Node = null

var screen_nodes: Dictionary = {}
var current_screen: Screen = Screen.NONE

func _ready():
	game_manager.ui_manager = self
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	
	if battle_hud:
		screen_nodes[Screen.BATTLE_HUD] = battle_hud
		battle_hud.destiny_design_opened.connect(_on_destiny_design_opened)
		battle_hud.map_requested.connect(get_node("/root/MapManager").show_dungeon_map)
		battle_hud.start_combat_requested.connect(game_manager.handle_start_combat)
		
		battle_hud.attack_stance_selected.connect(game_manager.handle_attack_stance)
		battle_hud.defense_stance_selected.connect(game_manager.handle_defense_stance)
		battle_hud.skill_1_used.connect(game_manager.use_skill_1)
		battle_hud.skill_2_used.connect(game_manager.use_skill_2)
		
		show_screen(Screen.BATTLE_HUD)
	else:
		show_screen(Screen.NONE)

func show_character_info(character: Character):
	if not is_instance_valid(status_popup):
		status_popup = STATUS_POPUP_SCENE.instantiate()
		add_child(status_popup)
	
	if status_popup.has_method("show_stats"):
		status_popup.show_stats(character)
		var mouse_pos = get_viewport().get_mouse_position()
		status_popup.global_position = mouse_pos + Vector2(20, 20)
		status_popup.call_deferred("_clamp_to_viewport")
		status_popup.show()

func show_screen(screen_type: Screen, instance: Node = null):
	if current_screen != Screen.NONE and screen_nodes.has(current_screen):
		var current_screen_node = screen_nodes[current_screen]
		current_screen_node.visible = false
		
		var is_temp = current_screen in [Screen.DUNGEON_MAP, Screen.DESTINY_DESIGN, Screen.END_OF_DUNGEON_OPTIONS, Screen.LOOT_OFFER, Screen.INVENTORY]
		if is_temp:
			current_screen_node.queue_free()
			screen_nodes.erase(current_screen)

	current_screen = screen_type
	if screen_type == Screen.NONE: return

	if not screen_nodes.has(screen_type):
		var new_screen_instance = instance
		if not new_screen_instance:
			match screen_type:
				Screen.DESTINY_DESIGN:
					new_screen_instance = destiny_design_screen_scene.instantiate()
					new_screen_instance.closed.connect(_on_destiny_design_closed)
				Screen.INVENTORY:
					if inventory_screen_scene:
						new_screen_instance = inventory_screen_scene.instantiate()
						if new_screen_instance.has_signal("inventory_closed"):
							new_screen_instance.inventory_closed.connect(_on_inventory_closed)
				Screen.LOOT_OFFER:
					if not loot_offer_screen_scene:
						loot_offer_screen_scene = load("res://ui/screens/LootOfferScreen.tscn")
					new_screen_instance = loot_offer_screen_scene.instantiate()
					if new_screen_instance.has_signal("closed"):
						new_screen_instance.closed.connect(_on_loot_offer_closed)
				Screen.END_OF_DUNGEON_OPTIONS:
					new_screen_instance = end_of_dungeon_screen_scene.instantiate()
					new_screen_instance.return_to_town_requested.connect(game_manager.handle_return_to_town)
					new_screen_instance.additional_exploration_requested.connect(game_manager.handle_additional_exploration)
				Screen.BATTLE_HUD:
					battle_hud = get_node_or_null("BattleHUD")
					if battle_hud: screen_nodes[Screen.BATTLE_HUD] = battle_hud

		if new_screen_instance:
			add_child(new_screen_instance)
			screen_nodes[screen_type] = new_screen_instance

	if screen_nodes.has(screen_type):
		screen_nodes[screen_type].visible = true
		if screen_type == Screen.BATTLE_HUD:
			move_child(screen_nodes[screen_type], 0)

func _on_battle_started():
	if battle_hud:
		battle_hud.set_destiny_button_enabled(false)
		if battle_hud.map_button: battle_hud.map_button.visible = false
		if battle_hud.start_combat_button: battle_hud.start_combat_button.visible = false

func _on_battle_ended(win: bool):
	if battle_hud:
		if win:
			battle_hud.set_destiny_button_enabled(true)
			battle_hud.show_map_button()
		else:
			battle_hud.set_destiny_button_enabled(false)

func _on_inventory_opened():
	show_screen(Screen.INVENTORY)

func _on_inventory_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.TOWN:
		show_screen(Screen.NONE)
	else:
		show_screen(Screen.BATTLE_HUD)

func _on_destiny_design_opened():
	show_screen(Screen.DESTINY_DESIGN)

func _on_destiny_design_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.TOWN:
		show_screen(Screen.NONE)
	else:
		show_screen(Screen.BATTLE_HUD)

func _on_loot_offer_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.BATTLE_END:
		if game_manager.current_battle_node_type == "boss":
			show_screen(Screen.END_OF_DUNGEON_OPTIONS)
		else:
			show_screen(Screen.BATTLE_HUD)

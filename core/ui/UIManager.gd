# UIManager.gd
class_name UIManager
extends CanvasLayer

func _init():
	layer = 150 # 다른 모든 UI(100~120)보다 높게 설정

enum Screen { NONE, GROWTH, CHARACTER_INFO, BATTLE_HUD, INVENTORY, DUNGEON_MAP, END_OF_DUNGEON_OPTIONS, LOOT_OFFER }

@export var growth_screen_scene: PackedScene
@export var character_info_screen_scene: PackedScene
@export var inventory_screen_scene: PackedScene
@export var end_of_dungeon_screen_scene: PackedScene
@export var loot_offer_screen_scene: PackedScene
@export var advantage_label_scene: PackedScene

@onready var advantage_container = get_node_or_null("AdvantageContainer")
@onready var battle_hud = get_node_or_null("BattleHUD")
@onready var game_manager: Node = get_node("/root/GameManager")

const STATUS_POPUP_SCENE = preload("res://ui/StatusPopup.tscn")
var status_popup: Node = null
var item_tooltip: Control = null # ItemTooltip 인스턴스 저장용

var screen_nodes: Dictionary = {}
var current_screen: Screen = Screen.NONE

func _ready():
	game_manager.ui_manager = self
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	
	if battle_hud:
		screen_nodes[Screen.BATTLE_HUD] = battle_hud
		battle_hud.growth_opened.connect(_on_growth_opened)
		battle_hud.inventory_opened.connect(_on_inventory_opened)
		battle_hud.map_requested.connect(get_node("/root/MapManager").show_dungeon_map)
		battle_hud.start_combat_requested.connect(game_manager.handle_start_combat)
		
		battle_hud.attack_stance_selected.connect(game_manager.handle_attack_stance)
		battle_hud.defense_stance_selected.connect(game_manager.handle_defense_stance)
		battle_hud.skill_1_used.connect(game_manager.use_skill_1)
		battle_hud.skill_2_used.connect(game_manager.use_skill_2)
		
		show_screen(Screen.BATTLE_HUD)
	else:
		show_screen(Screen.NONE)

func get_screen_node(screen_type: Screen) -> Node:
	if screen_nodes.has(screen_type):
		return screen_nodes[screen_type]
	return null

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
		if is_instance_valid(current_screen_node):
			current_screen_node.visible = false
		
		var is_temp = current_screen in [Screen.DUNGEON_MAP, Screen.GROWTH, Screen.END_OF_DUNGEON_OPTIONS, Screen.LOOT_OFFER, Screen.INVENTORY, Screen.CHARACTER_INFO]
		if is_temp:
			if is_instance_valid(current_screen_node):
				current_screen_node.queue_free()
			screen_nodes.erase(current_screen)

	current_screen = screen_type
	if screen_type == Screen.NONE: 
		# [수정] 아무 화면도 띄우지 않을 때는 기본적으로 BATTLE_HUD를 보여줌 (마을이 아닐 때)
		if game_manager and game_manager.current_game_phase != GameManager.GamePhase.TOWN:
			if screen_nodes.has(Screen.BATTLE_HUD):
				screen_nodes[Screen.BATTLE_HUD].visible = true
		return

	if not screen_nodes.has(screen_type):
		var new_screen_instance = instance
		if not new_screen_instance:
			match screen_type:
				Screen.GROWTH:
					# [v7.5 수정] 변수명 변경으로 인한 참조 소실 방어 로직
					if not growth_screen_scene:
						growth_screen_scene = load("res://ui/screens/DestinyDesignScreen.tscn")
					
					if growth_screen_scene:
						new_screen_instance = growth_screen_scene.instantiate()
						if new_screen_instance.has_signal("closed"):
							new_screen_instance.closed.connect(_on_growth_closed)
					else:
						printerr("UIManager: GROWTH 화면 씬을 로드할 수 없습니다.")
						
				Screen.CHARACTER_INFO:
					if not character_info_screen_scene:
						# 아직 생성되지 않은 경우를 대비해 나중에 경로 수정 필요
						var p = "res://ui/screens/CharacterInfoScreen.tscn"
						if FileAccess.file_exists(p):
							character_info_screen_scene = load(p)
					
					if character_info_screen_scene:
						new_screen_instance = character_info_screen_scene.instantiate()
					else:
						print("UIManager: CHARACTER_INFO 화면이 아직 구현되지 않았습니다.")
						
				Screen.INVENTORY:
					if not inventory_screen_scene:
						inventory_screen_scene = load("res://ui/screens/InventoryScreen.tscn")
					
					if inventory_screen_scene:
						new_screen_instance = inventory_screen_scene.instantiate()
						if is_instance_valid(new_screen_instance) and new_screen_instance.has_signal("inventory_closed"):
							new_screen_instance.inventory_closed.connect(_on_inventory_closed)
				Screen.LOOT_OFFER:
					if not loot_offer_screen_scene:
						loot_offer_screen_scene = load("res://ui/screens/LootOfferScreen.tscn")
					new_screen_instance = loot_offer_screen_scene.instantiate()
					if is_instance_valid(new_screen_instance) and new_screen_instance.has_signal("closed"):
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

func _on_growth_opened():
	show_screen(Screen.GROWTH)

func _on_growth_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.TOWN:
		show_screen(Screen.NONE)
	else:
		show_screen(Screen.BATTLE_HUD)

func _on_character_info_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.TOWN:
		show_screen(Screen.NONE)
	else:
		show_screen(Screen.BATTLE_HUD)

func _on_loot_offer_closed():
	var loot_manager = get_node_or_null("/root/LootManager")
	var is_boss_loot = false
	if loot_manager:
		is_boss_loot = loot_manager.get_loot_data().get("is_boss", false)
	
	if game_manager.current_game_phase == GameManager.GamePhase.BATTLE_END:
		if is_boss_loot:
			show_screen(Screen.END_OF_DUNGEON_OPTIONS)
		else:
			show_screen(Screen.BATTLE_HUD)

func show_item_tooltip(item: InventoryItem, global_pos: Vector2):
	if not is_instance_valid(item_tooltip):
		item_tooltip = ItemTooltip.new()
		add_child(item_tooltip)
	
	if item_tooltip.has_method("setup"):
		item_tooltip.setup(item)
	
	item_tooltip.global_position = global_pos + Vector2(20, 20)
	
	# 화면 밖으로 나가지 않게 조정
	var viewport_size = get_viewport().get_visible_rect().size
	if item_tooltip.global_position.x + item_tooltip.size.x > viewport_size.x:
		item_tooltip.global_position.x = global_pos.x - item_tooltip.size.x - 20
	if item_tooltip.global_position.y + item_tooltip.size.y > viewport_size.y:
		item_tooltip.global_position.y = viewport_size.y - item_tooltip.size.y - 10
		
	item_tooltip.show()

func hide_item_tooltip():
	if is_instance_valid(item_tooltip):
		item_tooltip.hide()

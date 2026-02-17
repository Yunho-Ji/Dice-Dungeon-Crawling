# UIManager.gd
class_name UIManager
extends CanvasLayer

enum Screen { NONE, DESTINY_DESIGN, BATTLE_HUD, INVENTORY, DUNGEON_MAP, END_OF_DUNGEON_OPTIONS, LOOT_OFFER }

@export var destiny_design_screen_scene: PackedScene
@export var inventory_screen_scene: PackedScene
@export var end_of_dungeon_screen_scene: PackedScene # New export for the end of dungeon screen
@export var loot_offer_screen_scene: PackedScene # [신규] 전리품 화면
@export var advantage_label_scene: PackedScene

# [수정] 자식 노드를 선택적으로 참조 (마을 등 HUD가 없는 곳에서도 작동하도록)
@onready var advantage_container = get_node_or_null("AdvantageContainer")
@onready var battle_hud = get_node_or_null("BattleHUD")
@onready var game_manager: GameManager = get_node("/root/GameManager") as GameManager

const STATUS_POPUP_SCENE = preload("res://ui/StatusPopup.tscn")
var status_popup: Node = null

var screen_nodes: Dictionary = {}
var current_screen: Screen = Screen.NONE

func _ready():
	# [신규] 전역 참조 등록
	game_manager.ui_manager = self
	
	# [복구] GameManager 시그널 연결
	game_manager.battle_started.connect(_on_battle_started)
	game_manager.battle_ended.connect(_on_battle_ended)
	
	if battle_hud:
		screen_nodes[Screen.BATTLE_HUD] = battle_hud
		# BattleHUD 시그널 연결
		battle_hud.destiny_design_opened.connect(_on_destiny_design_opened)
		battle_hud.map_requested.connect(get_node("/root/MapManager").show_dungeon_map)
		battle_hud.start_combat_requested.connect(game_manager.handle_start_combat)
		
		# 전투 관련 시그널을 GameManager에 직접 연결
		battle_hud.attack_stance_selected.connect(game_manager.handle_attack_stance)
		battle_hud.defense_stance_selected.connect(game_manager.handle_defense_stance)
		battle_hud.skill_1_used.connect(game_manager.use_skill_1)
		battle_hud.skill_2_used.connect(game_manager.use_skill_2)
		
		show_screen(Screen.BATTLE_HUD) # HUD가 있으면 HUD부터 표시
	else:
		show_screen(Screen.NONE)

## 캐릭터 상세 정보 팝업 표시
func show_character_info(character: Character):
	if not is_instance_valid(status_popup):
		status_popup = STATUS_POPUP_SCENE.instantiate()
		add_child(status_popup)
	
	if status_popup.has_method("show_stats"):
		status_popup.show_stats(character)
		# 팝업을 마우스 근처에 배치하되 화면 밖으로 나가지 않도록 함
		var mouse_pos = get_viewport().get_mouse_position()
		status_popup.global_position = mouse_pos + Vector2(20, 20)
		
		# 팝업이 크기를 계산할 시간을 준 뒤 클램핑 (Deferred)
		status_popup.call_deferred("_clamp_to_viewport")
		status_popup.show()

func show_screen(screen_type: Screen, instance: Node = null):
	# 현재 화면 숨기기
	if current_screen != Screen.NONE and screen_nodes.has(current_screen):
		var current_screen_node = screen_nodes[current_screen]
		current_screen_node.visible = false
		
		# 임시 화면(지도, 인벤토리, 운명설계 등)은 제거하여 메모리 해제
		var is_temp = current_screen in [Screen.DUNGEON_MAP, Screen.INVENTORY, Screen.DESTINY_DESIGN, Screen.END_OF_DUNGEON_OPTIONS, Screen.LOOT_OFFER]
		if is_temp:
			current_screen_node.queue_free()
			screen_nodes.erase(current_screen)

	current_screen = screen_type
	if screen_type == Screen.NONE: return

	# 새 화면 표시
	if not screen_nodes.has(screen_type):
		var new_screen_instance = instance
		if not new_screen_instance:
			match screen_type:
				Screen.DESTINY_DESIGN:
					new_screen_instance = destiny_design_screen_scene.instantiate()
					new_screen_instance.closed.connect(_on_destiny_design_closed)
					if game_manager.has_method("handle_dice_roll_request"):
						new_screen_instance.dice_roll_requested.connect(game_manager.handle_dice_roll_request)
				Screen.INVENTORY:
					if inventory_screen_scene:
						new_screen_instance = inventory_screen_scene.instantiate()
						if new_screen_instance.has_signal("closed"):
							new_screen_instance.closed.connect(_on_inventory_closed)
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
					# BattleHUD가 코드상 등록되지 않았다면 (예: 씬 전환 직후) 다시 찾기 시도
					battle_hud = get_node_or_null("BattleHUD")
					if battle_hud: screen_nodes[Screen.BATTLE_HUD] = battle_hud

		if new_screen_instance:
			add_child(new_screen_instance)
			screen_nodes[screen_type] = new_screen_instance

	if screen_nodes.has(screen_type):
		screen_nodes[screen_type].visible = true
		# HUD가 표시될 때는 최상단으로 오지 않도록 조정 (팝업이 위에 떠야 하므로)
		if screen_type == Screen.BATTLE_HUD:
			move_child(screen_nodes[screen_type], 0)

func show_end_of_dungeon_options():
	show_screen(Screen.END_OF_DUNGEON_OPTIONS)

# --- GameManager 시그널 핸들러 ---
func _on_battle_started():
	if battle_hud:
		battle_hud.set_destiny_button_enabled(false)
		# Hide both buttons when combat starts
		if battle_hud.map_button: battle_hud.map_button.visible = false
		if battle_hud.start_combat_button: battle_hud.start_combat_button.visible = false

func _on_battle_ended(win: bool):
	if battle_hud:
		if win:
			battle_hud.set_destiny_button_enabled(true)
			battle_hud.show_map_button()
		else: # 패배 시
			battle_hud.set_destiny_button_enabled(false)

# --- BattleHUD 시그널 핸들러 ---
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
	elif game_manager.current_game_phase == GameManager.GamePhase.PREPARE:
		# 던전 시작 초기 시퀀스가 끝났으므로 지도를 보여줌
		var map_manager = get_node("/root/MapManager")
		if map_manager:
			map_manager.show_dungeon_map()
	else:
		# 전투 중 또는 기타 상황에서는 BATTLE_HUD로 복구
		show_screen(Screen.BATTLE_HUD)
		if battle_hud:
			# [수정] 상태에 따라 적절한 버튼 표시
			if game_manager.current_game_phase == GameManager.GamePhase.READY_TO_BATTLE:
				battle_hud.show_start_combat_button()
			else:
				# 전투 종료 후(BATTLE_END)나 기타 경우에는 지도 버튼 표시
				battle_hud.show_map_button()

func _on_loot_offer_closed():
	if game_manager.current_game_phase == GameManager.GamePhase.BATTLE_END:
		# [신규] 보스전이었다면 결과 화면 표시
		if game_manager.current_battle_node_type == "boss":
			show_end_of_dungeon_options()
		else:
			# 일반 전투였다면 HUD 상태로 복구
			show_screen(Screen.BATTLE_HUD)

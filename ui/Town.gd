extends Control

const NPCData = preload("res://resources/characters/npc/NPCData.gd")

var town_manager # TownManager 싱글톤 인스턴스를 저장할 변수
var current_dialogue_screen: Node = null

@onready var time_display_label = $ContentArea/TimeDisplay
@onready var location_buttons = $ContentArea/LocationButtons
@onready var closing_message_label = $ContentArea/ClosingMessageLabel
@onready var start_expedition_button = $ContentArea/StartExpeditionButton
@onready var scene_manager: Node = get_node("/root/SceneManager")

@onready var player_name_label = $PlayerInfoPanel/HBox/VBox_Basic/PlayerName
@onready var level_info_label = $PlayerInfoPanel/HBox/VBox_Basic/LevelInfo
@onready var stats_label = $PlayerInfoPanel/HBox/VBox_Stats/StatsLabel
@onready var gold_label = $PlayerInfoPanel/HBox/VBox_Stats/GoldLabel

func _ready():
	town_manager = get_node("/root/TownManager")
	var player_manager = get_node("/root/PlayerManager")
	var economy_manager = get_node("/root/EconomyManager")
	var gm = get_node("/root/GameManager")
	
	if has_node("UIManager"):
		gm.ui_manager = $UIManager
	
	gm.current_game_phase = GameManager.GamePhase.TOWN

	town_manager.time_updated.connect(_on_time_updated)
	town_manager.town_closing_time_reached.connect(_on_town_closing_time_reached)
	start_expedition_button.pressed.connect(_on_start_expedition_button_pressed)
	
	_update_player_info()
	var em = get_node_or_null("/root/EconomyManager")
	if em and em.has_signal("gold_changed"):
		em.gold_changed.connect(func(_val): _update_player_info())
	
	_on_time_updated(town_manager.get_current_time_string())

	for button in location_buttons.get_children():
		button.pressed.connect(Callable(self, "_on_location_button_pressed").bind(button.name))

func _update_player_info():
	var pm = get_node("/root/PlayerManager")
	var em = get_node("/root/EconomyManager")
	player_name_label.text = "플레이어 (%s)" % pm.player_data.character_name
	level_info_label.text = "LV. %d (EXP: %d / %d)" % [1, 0, 100]
	
	if pm.current_player_stats:
		var stats = pm.current_player_stats
		stats_label.text = "HP: %d / ATK: %d / DEF: %d" % [
			stats.get_stat("health").computed_value,
			stats.get_stat("attack_power").computed_value,
			stats.get_stat("defense").computed_value
		]
	gold_label.text = "소지 골드: %d G" % em.get_gold()

func _on_time_updated(time_string: String):
	time_display_label.text = time_string

func _on_location_button_pressed(button_name: String):
	match button_name:
		"InnButton":
			var npc_data = load("res://resources/characters/npc/InnKeeper.tres")
			if npc_data: _open_npc_dialogue(npc_data)
		"GeneralStoreButton":
			var npc_data = load("res://resources/characters/npc/Merchant.tres")
			if npc_data: _open_npc_dialogue(npc_data)
		"BlacksmithButton":
			var npc_data = load("res://resources/characters/npc/Blacksmith.tres")
			if npc_data: _open_npc_dialogue(npc_data)
		_:
			print(button_name, " 방문 로직 미구현")
func _open_npc_dialogue(data: NPCData):
	if current_dialogue_screen:
		current_dialogue_screen.queue_free()

	# 건물 내부로 진입하는 느낌을 주기 위해 마을 배경/UI 숨김
	if has_node("ContentArea"):
		$ContentArea.visible = false

	var dialogue_script = load("res://ui/screens/NPCDialogueScreen.gd")
	var dialogue_screen = CanvasLayer.new()
	dialogue_screen.set_script(dialogue_script)
	add_child(dialogue_screen)

	dialogue_screen.setup(data)
	dialogue_screen.closed.connect(_on_npc_dialogue_closed.bind(dialogue_screen))
	current_dialogue_screen = dialogue_screen

# 대화창을 화면 좌측에 배치하고 뒷배경을 어둡게 처리하는 함수
# NPCDialogueScreen 내부에서 자체적으로 처리하도록 개선됨
func _setup_dialogue_layout(node: Node):
	# 이전의 중복된 dimmer 로직 제거 (NPCDialogueScreen이 자체 CanvasLayer와 Dimmer를 가짐)
	pass

# 노드를 화면 중앙에 배치하고 뒷배경을 어둡게 처리하는 헬퍼 함수 (기타 팝업용)
func _on_npc_dialogue_closed(action_type, param, screen):
	match action_type:
		NPCData.FunctionType.SHOP:
			_open_shop_screen(screen)
		NPCData.FunctionType.REST:
			_open_inn_screen()
			screen.queue_free()
		NPCData.FunctionType.ENCHANT:
			_open_enchant_screen(screen)
		NPCData.FunctionType.EXIT:
			if town_manager.spend_time_for_facility():
				print("Town: 대화 종료 후 시간이 흘렀습니다.")
			current_dialogue_screen = null
			
			# 마을 배경/UI 다시 표시
			if has_node("ContentArea"):
				$ContentArea.visible = true

func _open_enchant_screen(parent_screen: Node):
	var enchant_script = load("res://ui/screens/EnchantScreen.gd")
	var enchant_screen = PanelContainer.new()
	enchant_screen.set_script(enchant_script)
	
	parent_screen.set_grid_content(enchant_screen)
	enchant_screen.closed.connect(func(): _update_player_info())
	
	# [수정] 통합 거래 모드 활성화 (그리드 집중)
	if parent_screen.has_method("set_transaction_mode"):
		parent_screen.set_transaction_mode(true)
	if parent_screen.has_method("show_player_inventory"):
		parent_screen.show_player_inventory(true)

func _open_shop_screen(parent_screen: Node):
	# [디아블로 방식] 하나의 큰 그리드 생성
	var grid_scene = load("res://ui/inventory/CustomInventoryGrid.tscn")
	var shop_grid = grid_scene.instantiate()
	
	# 상점 그리드로 명시
	shop_grid.is_shop = true
	
	# 상점용 데이터 생성 (임시로 빈 10x10 그리드)
	shop_grid.inventory_data = InventoryData.new(Vector2i(10, 10))
	
	# 임시 상품 추가 (v7.5 테스트 장비 포함)
	shop_grid.inventory_data.add_item("test_plate_armor") # 중갑
	shop_grid.inventory_data.add_item("test_leather_armor") # 경갑
	shop_grid.inventory_data.add_item("basic_cloth_armor") # 천
	shop_grid.inventory_data.add_item("test_plate_boots")
	shop_grid.inventory_data.add_item("basic_leather_boots")
	
	shop_grid.inventory_data.add_item("test_grimoire_epic")
	
	parent_screen.set_grid_content(shop_grid)
	
	# [수정] 통합 거래 모드 활성화 (그리드 집중)
	if parent_screen.has_method("set_transaction_mode"):
		parent_screen.set_transaction_mode(true)
	if parent_screen.has_method("show_player_inventory"):
		parent_screen.show_player_inventory(true)

func _open_inn_screen():
	# 여관은 시스템 팝업이므로 별도 처리 (기존 방식 유지하되 중앙 정렬)
	var inn_script = load("res://ui/screens/TownInnScreen.gd")
	var inn_screen = PanelContainer.new()
	inn_screen.set_script(inn_script)
	add_child(inn_screen)
	_center_node(inn_screen)
	inn_screen.closed.connect(func(): 
		_update_player_info()
		# 여관을 닫을 때 마을 UI 복구
		if has_node("ContentArea"):
			$ContentArea.visible = true
	)

# 노드를 화면 중앙에 배치하고 뒷배경을 어둡게 처리하는 헬퍼 함수
func _center_node(node: Control):
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)
	node.tree_exited.connect(func(): if is_instance_valid(dimmer): dimmer.queue_free())
	
	var opaque_style = StyleBoxFlat.new()
	opaque_style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	opaque_style.border_width_left = 2
	opaque_style.border_width_top = 2
	opaque_style.border_width_right = 2
	opaque_style.border_width_bottom = 2
	opaque_style.border_color = Color(0.35, 0.4, 0.5, 1.0)
	opaque_style.corner_radius_top_left = 12
	opaque_style.corner_radius_top_right = 12
	opaque_style.corner_radius_bottom_right = 12
	opaque_style.corner_radius_bottom_left = 12
	opaque_style.content_margin_left = 20
	opaque_style.content_margin_right = 20
	opaque_style.content_margin_top = 20
	opaque_style.content_margin_bottom = 20
	node.add_theme_stylebox_override("panel", opaque_style)
	
	node.anchor_left = 0.5
	node.anchor_top = 0.5
	node.anchor_right = 0.5
	node.anchor_bottom = 0.5
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0
	node.grow_horizontal = Control.GROW_DIRECTION_BOTH
	node.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	move_child(dimmer, get_child_count() - 2)
	move_child(node, get_child_count() - 1)

func _on_town_closing_time_reached():
	for button in location_buttons.get_children():
		if button.name != "InnButton":
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)
	closing_message_label.text = "PM 23:00, 여관을 제외한 모든 상점이 문을 닫았습니다."
	closing_message_label.visible = true

func _on_start_expedition_button_pressed():
	scene_manager.go_to_map()

func _on_inventory_button_pressed():
	var gm = get_node("/root/GameManager")
	if gm.ui_manager:
		gm.ui_manager.show_screen(UIManager.Screen.INVENTORY)

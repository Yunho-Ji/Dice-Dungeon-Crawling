extends Control

var town_manager # TownManager 싱글톤 인스턴스를 저장할 변수

@onready var time_display_label = $TimeDisplay
@onready var location_buttons = $LocationButtons
@onready var closing_message_label = $ClosingMessageLabel
@onready var start_expedition_button = $StartExpeditionButton
@onready var scene_manager: SceneManager = get_node("/root/SceneManager")

@onready var player_name_label = $PlayerInfoPanel/HBox/VBox_Basic/PlayerName
@onready var level_info_label = $PlayerInfoPanel/HBox/VBox_Basic/LevelInfo
@onready var stats_label = $PlayerInfoPanel/HBox/VBox_Stats/StatsLabel
@onready var gold_label = $PlayerInfoPanel/HBox/VBox_Stats/GoldLabel

func _ready():
	# 싱글톤 인스턴스들을 가져옵니다.
	town_manager = get_node("/root/TownManager")
	var player_manager = get_node("/root/PlayerManager")
	var economy_manager = get_node("/root/EconomyManager")
	var gm = get_node("/root/GameManager")
	
	# [중요] 마을의 UIManager를 전역 참조로 등록하여 다른 매니저들이 접근 가능하게 함
	if has_node("UIManager"):
		gm.ui_manager = $UIManager
		print("Town: GameManager.ui_manager가 마을 UIManager로 교체되었습니다.")
	
	# [신규] 마을 페이즈 설정
	gm.current_game_phase = GameManager.GamePhase.TOWN

	# 인스턴스를 통해 시그널에 연결합니다.
	town_manager.time_updated.connect(_on_time_updated)
	town_manager.town_closing_time_reached.connect(_on_town_closing_time_reached)
	start_expedition_button.pressed.connect(_on_start_expedition_button_pressed)
	
	# [신규] 플레이어 데이터 업데이트
	_update_player_info()
	if economy_manager.has_signal("gold_changed"):
		economy_manager.gold_changed.connect(func(_val): _update_player_info())
	
	# 인스턴스를 통해 함수를 호출합니다.
	_on_time_updated(town_manager.get_current_time_string())

	for button in location_buttons.get_children():
		button.pressed.connect(Callable(self, "_on_location_button_pressed").bind(button.name))

func _update_player_info():
	var pm = get_node("/root/PlayerManager")
	var em = get_node("/root/EconomyManager")
	
	# 캐릭터 클래스 및 레벨 정보
	player_name_label.text = "플레이어 (%s)" % pm.player_data.character_name
	level_info_label.text = "LV. %d (EXP: %d / %d)" % [1, 0, 100] # 레벨 시스템 연동 예정
	
	# 스탯 정보 (최종 합산 수치 반영)
	if pm.current_player_stats:
		var stats = pm.current_player_stats
		stats_label.text = "HP: %d / ATK: %d / DEF: %d" % [
			stats.get_stat("health").computed_value,
			stats.get_stat("attack_power").computed_value,
			stats.get_stat("defense").computed_value
		]
	else:
		stats_label.text = "스탯 정보를 불러올 수 없습니다."
	
	# 골드 정보
	gold_label.text = "소지 골드: %d G" % em.get_gold()

func _on_time_updated(time_string: String):
	time_display_label.text = time_string

func _on_location_button_pressed(button_name: String):
	print("DEBUG: Town: Location clicked - ", button_name)
	
	match button_name:
		"InnButton":
			_open_inn_screen()
		"GeneralStoreButton":
			_open_shop_screen()
		"BlacksmithButton":
			print("대장간 방문: 장비 개선/수리 기능 구현 예정")
			if town_manager.spend_time_for_facility():
				print("Time advanced.")
		"TavernButton":
			print("선술집 방문: 현상금 수주/버프 기능 구현 예정")
			if town_manager.spend_time_for_facility():
				print("Time advanced.")
		"PrayerHouseButton":
			print("기도원 방문: 주사위 축복 기능 구현 예정")
			if town_manager.spend_time_for_facility():
				print("Time advanced.")

func _open_inn_screen():
	var inn_script = load("res://ui/screens/TownInnScreen.gd")
	var inn_screen = PanelContainer.new()
	inn_screen.set_script(inn_script)
	add_child(inn_screen)
	
	# 화면 중앙 배치
	inn_screen.set_anchors_preset(Control.PRESET_CENTER)
	inn_screen.grow_horizontal = Control.GROW_DIRECTION_BOTH
	inn_screen.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	inn_screen.closed.connect(func(): _update_player_info())

func _open_shop_screen():
	var shop_script = load("res://ui/screens/TownShopScreen.gd")
	var shop_screen = PanelContainer.new()
	shop_screen.set_script(shop_script)
	add_child(shop_screen)
	
	# 화면 중앙 배치
	shop_screen.set_anchors_preset(Control.PRESET_CENTER)
	shop_screen.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_screen.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	shop_screen.closed.connect(func(): _update_player_info())

func _on_town_closing_time_reached():
	print("마을 마감 시간 도달: 여관을 제외한 모든 장소 폐쇄")
	for button in location_buttons.get_children():
		if button.name != "InnButton":
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)

	closing_message_label.text = "PM 23:00, 여관을 제외한 모든 상점이 문을 닫았습니다."
	closing_message_label.visible = true

func _on_start_expedition_button_pressed():

	print("원정 시작 버튼 클릭: 지도로 이동")

	scene_manager.go_to_map()



func _on_inventory_button_pressed():
	print("마을: 가방 화면 호출")
	var gm = get_node("/root/GameManager")
	if gm.ui_manager:
		gm.ui_manager.show_screen(UIManager.Screen.INVENTORY)

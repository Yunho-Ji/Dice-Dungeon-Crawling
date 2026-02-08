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
	# 인스턴스를 통해 함수와 상수를 사용합니다.
	if button_name == "InnButton" and town_manager.get_current_time_minutes() >= town_manager.RETURN_TIME_MINUTES:
		town_manager.set_time_by_minutes(town_manager.RESET_TIME_MINUTES)
		print("여관 방문: 세이브 및 회복 기능 구현 예정. 시간 AM 11:00으로 초기화.")
	else:
		town_manager.advance_time_to_next_milestone()
		print("Visited ", button_name, ". Time advanced to next milestone.")

	match button_name:
		"InnButton":
			pass
		"BlacksmithButton":
			print("대장간 방문: 장비 개선/수리 기능 구현 예정")
		"TavernButton":
			print("선술집 방문: 현상금 수주/버프 기능 구현 예정")
		"PrayerHouseButton":			print("기도원 방문: 주사위 축복 기능 구현 예정")
		"GeneralStoreButton":
			print("잡화점 방문: 아이템 매매 기능 구현 예정")

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



	else:



		# UIManager가 없을 경우 오토로드된 InventoryScreen을 직접 호출하는 폴백 로직



		if get_node_or_null("/root/InventoryScreen"):



			get_node("/root/InventoryScreen").show_screen()



		else:



			printerr("Town: UIManager와 InventoryScreen 오토로드를 모두 찾을 수 없습니다.")

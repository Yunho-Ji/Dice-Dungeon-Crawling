extends Control


@onready var time_display_label = $TimeDisplay
@onready var location_buttons = $LocationButtons
@onready var closing_message_label = $ClosingMessageLabel
@onready var start_expedition_button = $StartExpeditionButton # New line

func _ready():
	TownManager.time_updated.connect(_on_time_updated)
	TownManager.town_closing_time_reached.connect(_on_town_closing_time_reached)
	start_expedition_button.pressed.connect(_on_start_expedition_button_pressed) # New line
	_on_time_updated(TownManager.get_current_time_string())

	for button in location_buttons.get_children():
		button.pressed.connect(Callable(self, "_on_location_button_pressed").bind(button.name))

func _on_time_updated(time_string: String):
	time_display_label.text = time_string

func _on_location_button_pressed(button_name: String):
	# Check if it's the Inn button and if the time is PM 23:00 or later
	if button_name == "InnButton" and TownManager.get_current_time_minutes() >= TownManager.RETURN_TIME_MINUTES:
		TownManager.set_time_by_minutes(TownManager.RESET_TIME_MINUTES)
		print("여관 방문: 세이브 및 회복 기능 구현 예정. 시간 AM 11:00으로 초기화.")
		# TODO: Add actual save logic here
		# TODO: Add player HP/MP/status recovery logic here
	else:
		TownManager.advance_time_to_next_milestone()
		print("Visited ", button_name, ". Time advanced to next milestone.")

	# TODO: Add specific logic for each location
	match button_name:
		"InnButton":
			# Logic moved above for time reset
			pass
		"BlacksmithButton":
			print("대장간 방문: 장비 개선/수리 기능 구현 예정")
		"TavernButton":
			print("선술집 방문: 현상금 수주/버프 기능 구현 예정")
		"PrayerHouseButton":
			print("기도원 방문: 주사위 축복 기능 구현 예정")
		"GeneralStoreButton":
			print("잡화점 방문: 아이템 매매 기능 구현 예정")

func _on_town_closing_time_reached():
	print("마을 마감 시간 도달: 여관을 제외한 모든 장소 폐쇄")
	for button in location_buttons.get_children():
		if button.name != "InnButton":
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5) # Visually indicate disabled
			# button.visible = false # Optionally hide them completely

	closing_message_label.text = "PM 23:00, 여관을 제외한 모든 상점이 문을 닫았습니다."
	closing_message_label.visible = true

func _on_start_expedition_button_pressed():
	print("원정 시작 버튼 클릭: 지도로 이동")
	get_node("/root/GameManager").go_to_map()

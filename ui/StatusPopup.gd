extends PanelContainer

@onready var stats_grid = $MarginContainer/VBoxContainer/StatsGrid
@onready var close_button = $MarginContainer/VBoxContainer/HBoxContainer/CloseButton

# 스탯 이름과 표시 이름을 매핑합니다.
const STAT_NAMES = {
	"attack_power": "공격력",
	"defense": "방어력",
	"attack_speed": "공격 속도",
	"recovery_power": "회복력",
	"luck": "행운",
	"resistance": "저항",
	"hp": "체력", # Combined HP display
	"mp": "마력"  # Combined MP display
}

# 드래그 상태를 추적하기 위한 변수
var dragging = false

func _ready():
	close_button.connect("pressed", _on_close_button_pressed)

# 마우스 입력을 처리하여 패널을 드래그하는 함수
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	
		if event is InputEventMouseMotion and dragging:
			position += event.relative

# 캐릭터의 스탯을 받아서 UI에 표시하는 함수
func show_stats(character: Character):
	print("StatusPopup: show_stats 호출됨")
	# 이전 스탯 정보 삭제
	for child in stats_grid.get_children():
		child.queue_free()

	# 새로운 스탯 정보 추가
	for stat_key in STAT_NAMES.keys():
		var stat_name = STAT_NAMES[stat_key]
		var value_text = "-"

		# 각 스탯에 맞는 getter 함수를 직접 호출하여 값을 가져옵니다.
		match stat_key:
			"hp":
				value_text = "%s/%s" % [character.get_current_hp(), character.get_max_hp()]
			"mp":
				value_text = "%s/%s" % [character.get_current_mp(), character.get_max_mp()]
			"attack_power":
				value_text = str(character.get_attack_power())
			"defense":
				value_text = str(character.get_defense())
			"attack_speed":
				value_text = str(character.get_attack_speed())
			"recovery_power":
				value_text = str(character.get_recovery_power())
			"luck":
				value_text = str(character.get_luck())
			"resistance":
				value_text = str(character.get_resistance())

		var label = Label.new()
		label.text = "%s: %s" % [stat_name, value_text]
		label.add_theme_color_override("font_color", Color.WHITE)
		stats_grid.add_child(label)

	# 팝업을 보이게 함
	show()

func _on_close_button_pressed():
	hide() # 또는 queue_free()를 사용하여 팝업을 완전히 제거할 수 있습니다.

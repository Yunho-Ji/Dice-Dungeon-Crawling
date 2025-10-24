extends PanelContainer

@onready var stats_grid = $MarginContainer/VBoxContainer/StatsGrid
@onready var close_button = $MarginContainer/VBoxContainer/HBoxContainer/CloseButton

# 스탯 이름과 표시 이름을 매핑합니다.
const STAT_NAMES = {
	"health": "체력",
	"current_mp": "마력",
	"attack_power": "공격력",
	"defense": "방어력",
	"attack_speed": "공격 속도",
	"recovery_power": "회복력",
	"luck": "행운",
	"resistance": "저항"
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
	print("DEBUG: StatusPopup: show_stats called for character: ", character.name)
	print("DEBUG: StatusPopup: Character instance ID: ", character.get_instance_id())
	if character.stats_manager and character.stats_manager.character_stats:
		for stat_key in character.stats_manager.character_stats.get_all_stat_keys():
			var stat = character.stats_manager.get_stat(stat_key)
			if stat:
				print("DEBUG: StatusPopup:   ", stat.key, ": base=", stat.base_value, ", current=", stat.current_value, ", computed=", stat.computed_value)
	else:
		printerr("ERROR: StatusPopup: Character's stats_manager or character_stats is invalid.")
	
	# 이전 스탯 정보 삭제
	for child in stats_grid.get_children():
		child.queue_free()

	# 새로운 스탯 정보 추가
	for stat in character.stats_manager.get_all_stats():
		var stat_name = STAT_NAMES.get(stat.key, stat.key) # 표시 이름이 없으면 키 자체를 사용
		var value_text = "-"

		# 체력과 마력은 현재/최대 값으로 표시
		if stat.key == "health" or stat.key == "current_mp":
			value_text = "%s/%s" % [stat.current_value, stat.computed_value]
		else:
			if stat.current_value != stat.computed_value:
				value_text = "%s (%s)" % [stat.current_value, stat.computed_value] # Current (Computed)
			else:
				value_text = str(stat.computed_value) # Just Computed (which is equal to current)

		var label = Label.new()
		label.text = "%s: %s" % [stat_name, value_text]
		label.add_theme_color_override("font_color", Color.WHITE)
		stats_grid.add_child(label)



	# 활성 상태 효과 정보 추가
	if not character.active_status_effects.is_empty():
		var se_label = Label.new()
		var effect_names = []
		for effect in character.active_status_effects:
			effect_names.append(effect.get_effect_name())
		se_label.text = "활성 효과: %s" % ", ".join(effect_names)
		se_label.add_theme_color_override("font_color", Color.CYAN)
		stats_grid.add_child(se_label)

	# 팝업을 보이게 함
	show()

func _on_close_button_pressed():
	hide() # 또는 queue_free()를 사용하여 팝업을 완전히 제거할 수 있습니다.

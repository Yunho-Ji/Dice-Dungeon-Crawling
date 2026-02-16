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
	"resistance": "저항",
	"intelligence": "지능",
	"agility": "민첩"
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
			accept_event()
	
	if event is InputEventMouseMotion and dragging:
		global_position += event.relative
		_clamp_to_viewport()
		accept_event()

func _clamp_to_viewport():
	var viewport_rect = get_viewport_rect()
	var panel_size = size
	
	global_position.x = clamp(global_position.x, 0, viewport_rect.size.x - panel_size.x)
	global_position.y = clamp(global_position.y, 0, viewport_rect.size.y - panel_size.y)

# 캐릭터의 스탯을 받아서 UI에 표시하는 함수
func show_stats(character: Character):
	print("DEBUG: StatusPopup: show_stats called for character: ", character.name)
	print("DEBUG: StatusPopup: Character instance ID: ", character.get_instance_id())
	
	if not character.current_stats:
		printerr("ERROR: StatusPopup: Character's current_stats is invalid.")
		return
		
	# 디버그 출력
	for stat_key in character.current_stats.get_all_stat_keys():
		var stat = character.current_stats.get_stat(stat_key)
		if stat:
			print("DEBUG: StatusPopup:   ", stat.key, ": base=", stat.base_value, ", current=", stat.current_value, ", computed=", stat.computed_value)
	
	# 이전 스탯 정보 삭제
	for child in stats_grid.get_children():
		child.queue_free()

	# 새로운 스탯 정보 추가
	for stat in character.current_stats.get_all_stats():
		if not STAT_NAMES.has(stat.key):
			continue # 허가되지 않은 스탯은 건너뜀
			
		var stat_name = STAT_NAMES.get(stat.key, stat.key)
		var value_text = "-"

		# 체력과 마력은 현재/최대 값으로 표시
		if stat.key == "health" or stat.key == "current_mp":
			value_text = "%s / %s" % [stat.current_value, stat.computed_value]
		else:
			# 그 외 모든 스탯(공격력, 방어력 등)은 보너스가 모두 합산된 최종 수치만 표기
			value_text = str(stat.computed_value)

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
extends PanelContainer

@onready var stats_grid = $MarginContainer/VBoxContainer/StatsGrid
@onready var close_button = $MarginContainer/VBoxContainer/HBoxContainer/CloseButton

# 스탯 이름과 표시 이름을 매핑합니다.
const STAT_NAMES = {
	"attack_power": "공격력",
	"max_hp": "최대 체력",
	"current_hp": "현재 체력",
	"defense": "방어력",
	"attack_speed": "공격 속도",
	"recovery_power": "회복력",
	"unused_stat_1": "(미사용)",
	"unused_stat_2": "(미사용)"
}

func _ready():
	close_button.connect("pressed", _on_close_button_pressed)

# 캐릭터의 스탯을 받아서 UI에 표시하는 함수
func show_stats(character: Character):
	print("StatusPopup: show_stats 호출됨")
	# 이전 스탯 정보 삭제
	for child in stats_grid.get_children():
		child.queue_free()

	# 새로운 스탯 정보 추가 (2행 4열)
	var stat_keys = STAT_NAMES.keys()
	for i in range(8):
		var stat_key = stat_keys[i]
		var stat_name = STAT_NAMES[stat_key]
		var value = "-"
		if character.has_method("get") and character.has(stat_key):
			value = str(character.get(stat_key))
		
		var label = Label.new()
		label.text = "%s: %s" % [stat_name, value]
		stats_grid.add_child(label)

	# 팝업을 보이게 함
	show()

func _on_close_button_pressed():
	hide() # 또는 queue_free()를 사용하여 팝업을 완전히 제거할 수 있습니다.

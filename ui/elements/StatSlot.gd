class_name StatSlot
extends VBoxContainer

# StatSlot.gd
# 스탯 슬롯: 주사위를 드롭하여 스탯을 강화하는 UI 요소

@onready var stat_name_label: Label = $StatNameLabel
@onready var slot_panel: Panel = $SlotPanel
@onready var assigned_value_label: Label = $SlotPanel/MarginContainer/VBoxContainer/AssignedValueLabel
@onready var current_value_label: Label = $SlotPanel/MarginContainer/VBoxContainer/CurrentValueLabel

@export var stat_name: String = ""
var current_stat_value: MyStat

# 스탯 이름 약어 맵
const STAT_ABBREVIATIONS = {
	"health": "HP",
	"attack_power": "ATK",
	"defense": "DEF",
	"attack_speed": "SPD",
	"current_mp": "MP",
	"recovery_power": "REC",
	"luck": "LCK",
	"resistance": "RES"
}

func _ready():
	# UI 드롭 데이터 수신 가능하도록 설정
	mouse_filter = Control.MOUSE_FILTER_PASS
	slot_panel.mouse_filter = Control.MOUSE_FILTER_PASS

# 드래그 데이터가 드롭 가능한지 확인
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("type") and data.type == "dice"):
		return false
	
	# [수정] 1회 1스탯 누적 규칙 적용
	var screen = _get_design_screen()
	if screen and screen.target_stat_name != "" and screen.target_stat_name != stat_name:
		return false # 이미 다른 스탯이 선택됨
		
	return true

# 데이터 드롭 시 처리
func _drop_data(_at_position: Vector2, data: Variant):
	if current_stat_value:
		var dice_modifier = MyIntStatModifier.new()
		dice_modifier.value = data.value
		dice_modifier.operation = MyStatModifier.Operation.ADD
		dice_modifier.target_stat_key = stat_name
		current_stat_value.add_modifier(dice_modifier)
		
		# [신규] 이번 세션의 누적 타겟으로 이 스탯을 고정
		var screen = _get_design_screen()
		if screen:
			screen.target_stat_name = stat_name
		
		# [수정] 데이터 삭제 대신 '사용됨' 상태로 플래그 업데이트
		if get_node("/root/DiceManager").has_method("mark_dice_as_used"):
			get_node("/root/DiceManager").mark_dice_as_used(data.sides, data.value, true)
		
		# 사용된 주사위 노드 제거 (UI에서만 제거)
		if data.has("source_node") and is_instance_valid(data.source_node):
			data.source_node.queue_free()

func _get_design_screen():
	var p = get_parent()
	while p:
		if p.name == "DestinyDesignScreen" or p.has_signal("closed"):
			return p
		p = p.get_parent()
	return null

# 스탯 객체 설정
func set_stat(p_stat_name: String, p_stat_value: MyStat):
	stat_name = p_stat_name
	if current_stat_value and current_stat_value.value_changed.is_connected(update_display):
		current_stat_value.value_changed.disconnect(update_display)
	
	current_stat_value = p_stat_value
	
	if current_stat_value and not current_stat_value.value_changed.is_connected(update_display):
		current_stat_value.value_changed.connect(update_display)
	
	update_display()

# 화면 갱신: 합산된 수치만 깔끔하게 표기
func update_display():
	# 약어 적용
	var display_name = STAT_ABBREVIATIONS.get(stat_name, stat_name.to_upper())
	stat_name_label.text = display_name
	
	# 기본 수치 라벨은 숨기거나 보조 용도로만 사용 (사용자 요청: 합산 수치만 표기)
	current_value_label.visible = false 
	
	if current_stat_value:
		# 중앙의 큰 라벨에 합산된 최종 수치(computed_value)를 표기
		assigned_value_label.text = str(current_stat_value.computed_value)
	else:
		assigned_value_label.text = "N/A"
	
	# 주사위 보너스 적용 여부에 따른 색상 강조
	var has_dice_modifier = false
	if current_stat_value:
		for modifier in current_stat_value.modifiers:
			if modifier is MyIntStatModifier and modifier.target_stat_key == stat_name:
				has_dice_modifier = true
				break
	
	if has_dice_modifier:
		slot_panel.modulate = Color(0.7, 1.0, 0.7) # 강화됨: 초록빛
		assigned_value_label.add_theme_color_override("font_color", Color.YELLOW) # 강화된 수치 강조
	else:
		slot_panel.modulate = Color(1, 1, 1)
		assigned_value_label.remove_theme_color_override("font_color")

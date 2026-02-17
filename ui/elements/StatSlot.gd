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
	"agi": "AGI",
	"vit": "VIT",
	"int_stat": "INT",
	"atk": "ATK",
	"spd": "SPD",
	"res": "RES",
	"spi": "SPI",
	"rec": "REC"
}

func _ready():
	# UI 드롭 데이터 수신 가능하도록 설정
	mouse_filter = Control.MOUSE_FILTER_PASS
	slot_panel.mouse_filter = Control.MOUSE_FILTER_PASS

# 드래그 데이터가 드롭 가능한지 확인
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("type") and data.type == "dice"):
		return false
	
	# [수정] 중복 투자 금지 규칙: 이미 주사위가 투입된 스탯은 차단
	var screen = _get_design_screen()
	if screen and stat_name in screen.invested_stat_names:
		return false # 이 스탯은 이번 세션에서 이미 사용됨
		
	return true

# 데이터 드롭 시 처리
func _drop_data(_at_position: Vector2, data: Variant):
	if current_stat_value:
		# [수정] 리스트 추가를 먼저 수행 (update_display의 판단 근거를 먼저 마련)
		var screen = _get_design_screen()
		if screen:
			if not stat_name in screen.invested_stat_names:
				screen.invested_stat_names.append(stat_name)
		
		# 보너스 적용 (이 호출이 update_display()를 트리거함)
		var dice_modifier = MyIntStatModifier.new()
		dice_modifier.value = data.value
		dice_modifier.operation = MyStatModifier.Operation.ADD
		dice_modifier.target_stat_key = stat_name
		current_stat_value.add_modifier(dice_modifier)
		
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
	
	# 기본 수치 라벨은 숨기거나 보조 용도로만 사용
	if is_instance_valid(current_value_label):
		current_value_label.visible = false 
	
	if current_stat_value:
		# [수정] 스탯 시스템의 최종 합산값(computed_value)을 가져옴
		assigned_value_label.text = str(int(current_stat_value.computed_value))
	else:
		assigned_value_label.text = "0"
	
	# [수정] 주사위 보너스 적용 여부에 따른 색상 강조 (이번 세션에 투자된 스탯만 표시)
	var is_invested_now = false
	var screen = _get_design_screen()
	if screen and "invested_stat_names" in screen:
		is_invested_now = stat_name in screen.invested_stat_names
	
	if is_invested_now:
		slot_panel.modulate = Color(0.7, 1.0, 0.7) # 이번 세션에서 강화됨: 초록빛
		assigned_value_label.add_theme_color_override("font_color", Color.YELLOW) # 강화된 수치 강조
	else:
		slot_panel.modulate = Color(1, 1, 1) # 평상시 또는 이전 세션 강화분은 기본 색상
		assigned_value_label.remove_theme_color_override("font_color")

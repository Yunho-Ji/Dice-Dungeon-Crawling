class_name DestinyDie
extends Control

# --- 노드 참조 ---
@onready var visual = $DiceVisual  # 공통 시각화 컴포넌트

# --- 주사위 데이터 ---
var dice_sides: int = 6
var result_value: int = 1
var is_judgment: bool = false

# --- 등급별 색상 정의 ---
const COLOR_COMMON = Color("808b96")      # 일반: 회색
const COLOR_ELITE = Color("8e44ad")       # 엘리트: 보라색
const COLOR_LEGENDARY = Color("e67e22")   # 전설: 주황색
const COLOR_JUDGMENT = Color("c0392b")    # 판정용: 빨간색

func _ready():
	# UI 드래그 앤 드롭 입력을 허용함
	mouse_filter = Control.MOUSE_FILTER_STOP

# 드래그 시작 시 데이터를 구성하는 함수
func _get_drag_data(_at_position):
	var drag_preview = Control.new()
	# 현재 비주얼을 복제하여 마우스 커서에 표시
	var preview_visual = visual.duplicate()
	preview_visual.position = Vector2.ZERO
	drag_preview.add_child(preview_visual)
	
	set_drag_preview(drag_preview)
	
	return {
		"type": "dice",
		"value": result_value,
		"sides": dice_sides,
		"source_node": self
	}

# 주사위의 초기 상태를 설정하는 함수 (주로 외부 매니저에서 호출)
func setup(sides: int, value: int, p_is_judgment: bool = false):
	dice_sides = maxi(1, sides)
	result_value = value
	is_judgment = p_is_judgment
	
	# 비주얼 컴포넌트 초기화
	visual.setup(dice_sides, result_value, _get_tier_color())
	show_result()

# 등급에 따른 색상을 반환함
func _get_tier_color() -> Color:
	if is_judgment: return COLOR_JUDGMENT
	match dice_sides:
		4, 6, 8, 10: return COLOR_COMMON
		12: return COLOR_ELITE
		20: return COLOR_LEGENDARY
		_: return COLOR_COMMON

# 주사위 굴리기 애니메이션 (UI 버전)
func play_roll_animation():
	for i in range(14):
		# 0~6프레임을 순환하며 굴러가는 효과 연출
		visual.sync_frame(i % 7)
		await get_tree().create_timer(0.05).timeout
	show_result()

# 결과값을 확정하여 표시하는 함수
func show_result():
	# 비주얼 컴포넌트의 텍스처를 결과값에 맞춰 갱신
	visual.current_value = result_value
	visual._update_number_texture()
	# 정지 프레임(6번)으로 설정
	visual.sync_frame(6)
	modulate.a = 1.0

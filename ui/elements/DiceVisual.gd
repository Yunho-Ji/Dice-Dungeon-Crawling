# DiceVisual.gd
# 주사위의 시각적 표현을 담당하는 공통 컴포넌트

extends Node2D

# --- 노드 참조 ---
@onready var base = $DiceBase
@onready var number = $DiceNumber

# --- 정적 캐시 (메모리 절약 및 성능 향상) ---
static var texture_cache: Dictionary = {}

# --- 상태 변수 ---
var current_sides: int = 6
var current_value: int = 1
var current_tier_color: Color = Color.WHITE

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# 주사위 외형 설정
func setup(sides: int, value: int, tier_color: Color):
	current_sides = sides
	current_value = value
	current_tier_color = tier_color
	
	# 몸체 설정
	var base_path = "res://assets/sprites/assets/D&D Dice/d%d.png" % sides
	base.texture = _get_cached_texture(base_path)
	
	_update_number_texture()
	
	base.self_modulate = tier_color
	number.self_modulate = tier_color
	
	# [수정] 몸체는 항상 기본적으로 보임
	base.visible = true

# 텍스처를 메모리에서 즉시 가져오는 함수
func _get_cached_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path): return null
	if not texture_cache.has(path):
		texture_cache[path] = load(path) # 최초 1회만 로드
	return texture_cache[path]

# 숫자 텍스처 갱신 (고속 처리 버전)
func _update_number_texture():
	var num_suffix = ""
	if current_sides == 20: num_suffix = str(((current_value - 1) / 5) + 1) if current_value > 5 else ""
	elif current_sides == 12: num_suffix = str(((current_value - 1) / 6) + 1) if current_value > 6 else ""
	elif current_sides == 10: num_suffix = str(((current_value - 1) / 5) + 1) if current_value > 5 else ""
	
	var num_path = "res://assets/sprites/assets/D&D Dice/d%d_numbers%s.png" % [current_sides, num_suffix]
	var tex = _get_cached_texture(num_path)
	
	if tex:
		number.texture = tex
		number.vframes = maxi(1, tex.get_height() / 48)
		number.self_modulate = current_tier_color
		# [수정] 몸체는 절대 숨기지 않음
		base.visible = true
		number.visible = true
	else:
		number.texture = null
		base.visible = true

# 프레임 동기화 (결과 확정용)
func sync_frame(frame_idx: int):
	var f = clampi(frame_idx, 0, 6)
	base.frame = f
	
	if f == 6 and number.texture:
		# 정지 프레임(6): 숫자 표시 모드
		var face_index = 0
		if current_sides == 20: face_index = (current_value - 1) % 5
		elif current_sides == 12: face_index = (current_value - 1) % 6
		elif current_sides == 10: face_index = (current_value - 1) % 5
		else: face_index = current_value - 1
		
		face_index = clampi(face_index, 0, number.vframes - 1)
		number.frame = face_index * 7 + f
		
		# 밝기 중첩 방지: 숫자 에셋에 몸체가 포함되어 있으므로 Base는 숨김
		number.visible = true
		base.visible = false
	else:
		# 구르기 프레임(0~5): 몸체만 표시
		number.visible = false
		base.visible = true

# 구르기 프레임 동기화 (순차 번호 매핑 지원)
func sync_rolling_frame(frame_idx: int, show_number: bool = false):
	var f = clampi(frame_idx, 0, 6)
	base.frame = f
	
	if show_number and number.texture:
		var face_index = 0
		if current_sides == 20: face_index = (current_value - 1) % 5
		elif current_sides == 12: face_index = (current_value - 1) % 6
		elif current_sides == 10: face_index = (current_value - 1) % 5
		else: face_index = current_value - 1
		
		face_index = clampi(face_index, 0, number.vframes - 1)
		number.frame = face_index * 7 + f
		number.visible = true
		
		# [수정] 구르는 동안(0~5)에는 베이스(몸체)를 항상 보여주어 애니메이션이 끊기지 않게 합니다.
		# 최종 정지 프레임(6)에서만 베이스를 숨겨 숫자 에셋과의 겹침 및 밝기 중첩을 방지합니다.
		if f == 6:
			base.visible = false
		else:
			base.visible = true
		
		number.visible = true
	else:
		# 숫자가 없는 경우(또는 안 보여주는 경우)에만 베이스(몸체)를 보여줍니다.
		number.visible = false
		base.visible = true

# 구르기 상태 설정 (숫자를 숨기지 않고 계속 업데이트하도록 함)
func set_rolling(is_rolling: bool):
	# 기술적으로 가능함을 보여주기 위해 숫자를 숨기지 않습니다.
	# 대신 _update_number_texture를 애니메이션 루프에서 호출하도록 설계합니다.
	number.visible = true 
	if not is_rolling and number.texture != null:
		base.visible = false
	else:
		base.visible = (number.texture == null)
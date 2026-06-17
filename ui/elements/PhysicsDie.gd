extends RigidBody2D

# -----------------------------------------------------------------------------
# [혁신] 물리 모멘텀 기반 주사위 애니메이션 시스템 (PhysicsDie)
# -----------------------------------------------------------------------------
# - 기존의 await 기반 루프를 폐기하고 물리 속도와 프레임을 실시간 동기화합니다.
# - 1~5 프레임: 속도 비례 롤링
# - 6 프레임: 충돌 및 감속 시 잔상/흔들림
# - 7 프레임: 완전 정지 후 결과 확정 및 정자세 보정
# -----------------------------------------------------------------------------

# --- 노드 참조 ---
@onready var visual = $DiceVisual

# --- 주사위 데이터 ---
var dice_sides: int = 6
var result_value: int = 1
var is_judgment: bool = false
var is_stopped: bool = false
var roll_time: float = 0.0
const MIN_ROLL_TIME = 0.6 

# --- [신규] 애니메이션 제어 변수 ---
var _rolling_frame_timer: float = 0.0
var _current_rolling_idx: int = 0
var _debug_label: Label = null
const MOMENTUM_ROLL_THRESHOLD = 80.0 # 롤링 유지 임계치
const MOMENTUM_STOP_THRESHOLD = 15.0 # 완전 정지 판단 임계치

signal stopped(final_value)

func _ready():
	# 물리 설정: CCD(연속 충돌 감지) 활성화하여 벽 뚫림 방지
	continuous_cd = 2 
	linear_damp = 1.6 # 감속 소폭 강화
	angular_damp = 2.2 # 회전 감속 강화
	
	# 충돌 감지 활성화
	contact_monitor = true
	max_contacts_reported = 4
	
	rotation = randf() * TAU
	input_event.connect(_on_input_event)
	sleeping_state_changed.connect(_on_sleeping_state_changed)

	# [디버그] 개발자 모드용 라벨 추가
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("is_developer_mode"):
		_debug_label = Label.new()
		_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_debug_label.add_theme_font_size_override("font_size", 14)
		_debug_label.modulate = Color.YELLOW
		_debug_label.position = Vector2(-20, -40) # 주사위 위쪽
		add_child(_debug_label)

# 주사위 등급 및 질량 설정
func setup(sides: int, p_is_judgment: bool = false):
	dice_sides = maxi(1, sides)
	is_judgment = p_is_judgment
	
	# 등급별 질량 차등 부여
	if dice_sides >= 20:
		mass = 2.2
	else:
		mass = 1.0
		
	var tier_color = _get_tier_color()
	visual.setup(dice_sides, 1, tier_color)

func _get_tier_color() -> Color:
	if is_judgment: return Color("c0392b")
	match dice_sides:
		4, 6, 8, 10: return Color("808b96")
		12: return Color("8e44ad")
		20: return Color("e67e22")
		_: return Color("808b96")

func _physics_process(delta):
	if is_stopped: return
	
	# 1. Y-Sorting (Z-index 기반 겹침 방지)
	z_index = int(global_position.y / 10.0)

	# 2. 아레나 이탈 방지 (Fail-safe)
	if global_position.x < 150 or global_position.x > 1050 or global_position.y < -50 or global_position.y > 700:
		global_position = Vector2(600, 324)
		linear_velocity *= 0.1
		print("DEBUG: 주사위 장외 이탈 복구")

	roll_time += delta
	
	# 3. [핵심] 물리 모멘텀 기반 애니메이션 동기화
	var momentum = linear_velocity.length() + abs(angular_velocity)
	_update_animation_by_momentum(momentum, delta)

	# 4. 정지 판단 보강
	if roll_time > MIN_ROLL_TIME:
		# 속도가 충분히 낮거나 물리 엔진이 정지(sleeping) 상태면 즉시 정지 처리
		if momentum < MOMENTUM_STOP_THRESHOLD or sleeping:
			_on_stopped()

func _update_animation_by_momentum(momentum: float, delta: float):
	# [개선] 멈추기 직전까지 저속 롤링을 유지하여 물리적 위화감 제거
	if momentum > 5.0:
		# 속도에 비례하여 프레임 속도를 조절 (속도가 낮을수록 프레임 전환이 느려짐)
		var frame_speed = clamp(0.1 * (400.0 / (momentum + 50.0)), 0.05, 0.25)
		_rolling_frame_timer += delta
		
		if _rolling_frame_timer > frame_speed:
			_rolling_frame_timer = 0.0
			_current_rolling_idx = (_current_rolling_idx + 1) % 5
			visual.sync_rolling_frame(_current_rolling_idx, false)
	
func launch(direction: Vector2, power: float):
	is_stopped = false
	freeze = false
	sleeping = false
	roll_time = 0.0
	
	# 물리 임펄스 가함
	var impulse_strength = (power * 5.5) + 250.0
	var impulse = direction * impulse_strength
	apply_central_impulse(impulse)
	apply_torque_impulse(randf_range(-200.0, 200.0))
	
	visual.set_rolling(true)

func _on_sleeping_state_changed():
	if sleeping and not is_stopped:
		_on_stopped()

func _on_stopped():
	if is_stopped: return
	is_stopped = true
	
	# 물리 연산 중지 및 동적 상태 해제
	freeze = true
	sleeping = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# 결과값 확정
	result_value = randi() % dice_sides + 1
	
	# 디버그 라벨 및 콘솔 출력
	if _debug_label:
		_debug_label.text = "Result: %d" % result_value
	print("[Dice Debug] Sides: D%d, Result: %d, Pos: %s" % [dice_sides, result_value, global_position])
	
	# [마감 고도화] 단계별 안착 연출
	# 1단계: 6프레임(index 5, 잔상)을 아주 짧게(0.06초) 보여주어 '충격' 표현
	visual.sync_rolling_frame(5, false) 
	await get_tree().create_timer(0.06).timeout
	
	# 2단계: 7프레임(index 6, 결과) 확정
	visual.current_value = result_value
	visual._update_number_texture()
	visual.sync_frame(6)
	
	# 3단계: 시각적 정자세 보정 및 스케일 바운스 (착지 타격감 부여)
	var tween = create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# 회전값 보정
	tween.tween_property(self, "rotation", 0.0, 0.25)
	# 스케일 팝핑 (퉁~ 하고 튀어오르는 느낌)
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1)
	tween.chain().tween_property(visual, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 크리티컬 연출 (D20 최대값 등)
	if result_value == dice_sides:
		_play_critical_effect()
	
	await get_tree().create_timer(0.4).timeout
	stopped.emit(result_value)

func _play_critical_effect():
	# [임시] 향후 파티클이나 화면 진동 추가 가능
	var tween = create_tween()
	tween.tween_property(visual, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.2)

func _on_input_event(_viewport, event, _shape_idx):
	if is_stopped and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var drag_data = {"type": "dice", "value": result_value, "sides": dice_sides, "source_node": self}
		var drag_control = Control.new()
		get_parent().add_child(drag_control)
		drag_control.global_position = get_global_mouse_position()
		var preview = Control.new()
		var preview_visual = visual.duplicate()
		preview_visual.position = Vector2.ZERO
		preview.add_child(preview_visual)
		drag_control.force_drag(drag_data, preview)
		drag_control.queue_free()
		visible = false

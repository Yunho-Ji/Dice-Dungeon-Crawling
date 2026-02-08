extends RigidBody2D

# --- 노드 참조 ---
@onready var visual = $DiceVisual
@onready var sfx_player = AudioStreamPlayer2D.new()

# --- 주사위 데이터 ---
var dice_sides: int = 6
var result_value: int = 1
var is_judgment: bool = false
var is_stopped: bool = false
var roll_time: float = 0.0
const MIN_ROLL_TIME = 0.6 

signal stopped(final_value)

func _ready():
	# 물리 설정: CCD(연속 충돌 감지) 활성화하여 벽 뚫림 방지
	continuous_cd = 2 
	linear_damp = 1.5 # [수정] 감속 대폭 강화 (0.8 -> 1.5)
	angular_damp = 2.0 # [수정] 회전 감속 강화 (1.5 -> 2.0)
	
	# 충돌 감지 활성화
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	
	add_child(sfx_player)
	rotation = randf() * TAU
	input_event.connect(_on_input_event)

# 주사위 등급 및 질량 설정
func setup(sides: int, p_is_judgment: bool = false):
	dice_sides = maxi(1, sides)
	is_judgment = p_is_judgment
	
	# 등급별 질량 차등 부여 (Legendary > Common)
	var tier_color = _get_tier_color()
	if dice_sides >= 20:
		mass = 2.0
	else:
		mass = 1.0
		
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
	
	# [신규] 입체감(Depth) 연출을 위해 Y 좌표에 따라 z_index 조절
	# 아래에 있는 주사위가 위로 보이게 하여 겹침 시 몰입도 방해 최소화
	z_index = int(global_position.y / 10.0)

	# [수정] 아레나 이탈 방지 Fail-safe 로직 (여유치 50px 추가)
	# 주사위가 벽에 충돌하는 것은 정상이며, 벽을 완전히 뚫고 나갔을 때만 복구함
	if global_position.x < 200 or global_position.x > 1002 or global_position.y < 10 or global_position.y > 638:
		global_position = Vector2(600, 324)
		linear_velocity *= 0.2 # 속도를 대폭 줄여 안정화
		print("DEBUG: 주사위 이탈 감지(실제 이탈) -> 중앙 복구")

	roll_time += delta
	if roll_time > MIN_ROLL_TIME:
		if linear_velocity.length() < 12.0 and abs(angular_velocity) < 1.0:
			_on_stopped()

# 충돌 시 'Clack' 사운드
func _on_body_entered(_body):
	if linear_velocity.length() > 20:
		pass

# 주사위가 멈췄을 때
func _on_stopped():
	if is_stopped: return
	is_stopped = true
	
	if dice_sides >= 20:
		Engine.time_scale = 0.2
		await get_tree().create_timer(0.2 * Engine.time_scale).timeout
		Engine.time_scale = 1.0

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	
	# [수정] 멈춘 순간 결과값 확정
	# 기존: 멈추고 나서 랜덤값 생성 -> 눈금 튐 발생
	# 변경: 결과값은 생성하지만, 시각적 갱신 전에 '굴러가는 모션'을 정지하고 결과 프레임으로 즉시 교체하지 않음
	result_value = randi() % dice_sides + 1
	
	# 비주얼 업데이트: 결과값 설정
	visual.current_value = result_value
	visual._update_number_texture()
	
	# [중요] '굴러가는 애니메이션' 코루틴이 프레임을 계속 바꾸지 못하게 막아야 함
	# _animate_rolling 함수 내의 while loop 조건(is_stopped)에 의해 자동으로 멈춤
	
	# 멈춘 후 최종 결과 프레임(보통 6번이나 정면 샷)으로 확실하게 고정
	visual.sync_frame(6) 
	
	await get_tree().create_timer(0.3).timeout
	stopped.emit(result_value)

func launch(direction: Vector2, power: float):
	is_stopped = false
	freeze = false
	roll_time = 0.0
	
	# [수정] 물리 공식 4차 재조정 (입력: 0~100)
	# 최소 힘(200), 최대 힘(700)으로 더 좁혀서 안정적인 속도 제공
	var impulse_strength = (power * 5.0) + 200.0
	var impulse = direction * impulse_strength
	
	apply_central_impulse(impulse)
	apply_torque_impulse(randf_range(-150.0, 150.0))
	
	# 비주얼 상태 업데이트 (눈 숨기기 모드 진입)
	if visual.has_method("set_rolling"):
		visual.set_rolling(true)
		
	_animate_rolling()

func _animate_rolling():
	# [수정] is_stopped가 true가 되면 루프 즉시 종료
	while not is_stopped:
		# 구르는 동안은 비주얼의 구르기 전용 프레임 함수 호출
		if visual.has_method("sync_rolling_frame"):
			visual.sync_rolling_frame(randi() % 6)
		
		await get_tree().create_timer(randf_range(0.06, 0.12)).timeout
	
	# 루프 종료 후에는 _on_stopped에서 최종 정지 프레임 처리

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
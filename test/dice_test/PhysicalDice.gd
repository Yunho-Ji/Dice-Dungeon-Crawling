extends RigidBody2D
class_name PhysicalDice

# -----------------------------------------------------------------------------
# [설계] 2D 물리 모멘텀 기반 주사위 뼈대 매핑 (PhysicalDice)
# -----------------------------------------------------------------------------
# - 1~5 프레임: 고속/저속 롤링 애니메이션
# - 6 프레임: 충돌 및 속도 저하 시의 잔상/흔들림
# - 7 프레임: 완전 정지 후 결과 확정
# -----------------------------------------------------------------------------

signal roll_finished(value: int)

@export var dice_sides: int = 6
@export var momentum_threshold_rolling: float = 100.0 # 롤링 유지 임계치
@export var momentum_threshold_stop: float = 10.0    # 완전 정지 판단 임계치

var _current_value: int = 0
var _is_rolling: bool = false
var _final_result_set: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# 물리 초기 설정
	contact_monitor = true
	max_contacts_reported = 3
	can_sleep = true
	
	# 초기 난수 할당 (굴리기 전 미리 결정)
	_current_value = randi_range(1, dice_sides)
	
	# 시그널 연결 (수동 정지 감지용)
	sleeping_state_changed.connect(_on_sleeping_state_changed)

func _physics_process(_delta):
	if not _is_rolling: return
	
	var momentum = linear_velocity.length() + abs(angular_velocity)
	
	if momentum > momentum_threshold_rolling:
		# [상태 1] 맹렬한 롤링 (1~5프레임 반복)
		# 물리 속도에 비례하여 애니메이션 속도 조절 가능
		sprite.speed_scale = clamp(momentum / 500.0, 0.5, 3.0)
		_play_rolling_animation()
	elif momentum > momentum_threshold_stop:
		# [상태 2] 속도 저하 및 잔상 (6프레임 활용)
		# 1~5프레임 사이사이에 6프레임을 섞거나 6프레임으로 고정 전 단계
		sprite.frame = 5 # 6프레임 (0-indexed)
		sprite.stop()
	
	# 겹침 방지 보조 로직: 너무 오래 굴러가면 강제 수면 유도 가능
	if _is_rolling and momentum < 1.0 and not sleeping:
		sleeping = true

func throw(force: Vector2, torque: float):
	_is_rolling = true
	_final_result_set = false
	sleeping = false
	apply_central_impulse(force)
	apply_torque_impulse(torque)

func _play_rolling_animation():
	if sprite.frame >= 5: # 프레임 6(잔상) 이상으로 넘어가지 않게 제한
		sprite.frame = 0
	sprite.play()

func _on_sleeping_state_changed():
	if sleeping and _is_rolling:
		_finish_roll()

func _finish_roll():
	_is_rolling = false
	# [상태 3] 완전 정지 및 결과 확정 (7프레임)
	sprite.stop()
	sprite.frame = 6 # 7프레임 (0-indexed)
	
	# 실제 결과 값 텍스처 매핑 (여기서는 로그로 대체)
	print("주사위 결과 확정: ", _current_value)
	
	# 회전값 보정 (시각적으로 정자세로 보이게)
	var tween = create_tween()
	tween.tween_property(self, "rotation", 0.0, 0.1)
	
	roll_finished.emit(_current_value)

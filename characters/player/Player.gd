extends "res://characters/Character.gd"
class_name Player

@export var initial_position: Vector2 = Vector2(200, 300) # 기본 위치 설정

# 플레이어 스킬 (모듈화 준비)
var active_skills: Array = []
var passive_skills: Array = []

var _attack_committed: bool = false # 공격이 한 번만 적용되도록 보장하는 플래그

func _ready():
	super._ready()
	position = initial_position # 초기 위치 설정

func _process(delta: float):
	if target == null or not is_instance_valid(target) or target.current_hp <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	super._process(delta) # Character의 _process 로직 호출

func attack(_target_node: CharacterBody2D):
	# 이 함수는 하위 클래스에서 오버라이드하여 애니메이션을 재생하고,
	# 공격 플래그를 리셋하는 역할을 합니다.
	_attack_committed = false
	pass

func apply_dice_rolls(dice_rolls: Array):
	attack_power += dice_rolls[0] # 가장 높은 값
	max_hp += dice_rolls[1]       # 두 번째 높은 값
	current_hp = min(current_hp + dice_rolls[1], max_hp) # 현재 체력은 최대 체력을 초과하지 않도록 증가
	defense += dice_rolls[2]      # 세 번째 높은 값
	attack_speed += dice_rolls[3] # 네 번째 높은 값 (공격속도는 높을수록 빠름)

	print("플레이어 스탯 업데이트됨: HP:", current_hp, ", 공격:", attack_power, ", 방어:", defense, ", 속도:", attack_speed, ", 회복:", recovery_power)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Player 클릭 감지!")
		if ui_manager:
			print("UIManager 유효함. 팝업 표시 요청.")
			ui_manager.show_status_popup(self)
		else:
			printerr("오류: UIManager 참조가 Player에서 null입니다!")

func _on_animation_finished():
	# 이 함수는 하위 클래스에서 오버라이드하여 애니메이션 종료 후 로직을 처리합니다.
	# Player는 이들을 직접 구현하지 않습니다.
	pass

func _on_visibility_changed():
	# 이 함수는 하위 클래스에서 오버라이드하여 가시성 변경 로직을 처리합니다.
	# Player는 이들을 직접 구현하지 않습니다.
	pass

func set_ui_manager(manager):
	ui_manager = manager
	print("Player에 UIManager 설정됨")
	if ui_manager == null:
			printerr("경고: Player에 설정된 UIManager가 null입니다.")

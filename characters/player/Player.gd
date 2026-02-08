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
	if target == null or not is_instance_valid(target) or target.current_stats.get_stat("health").computed_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	super._process(delta) # Character의 _process 로직 호출

func attack(_target_node: CharacterBody2D):
	# 이 함수는 하위 클래스에서 오버라이드하여 애니메이션을 재생하고,
	# 공격 플래그를 리셋하는 역할을 합니다.
	_attack_committed = false
	pass

func apply_dice_rolls(_dice_rolls: Array):
	# This function is now deprecated. Stat application is handled by the
	# drag-and-drop UI (StatSlot.gd) which calls apply_dice_to_stat directly.
	pass



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

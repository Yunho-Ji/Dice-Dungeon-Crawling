# test_StatManager.gd
# StatManager의 핵심 계산 로직이 의도대로 작동하는지 검증합니다.
extends "res://addons/gut/test.gd"

var StatManagerClass = load("res://core/StatManager.gd")
var stat_manager

func before_each():
	# 각 테스트 시작 전에 StatManager 인스턴스를 새로 생성하여 독립성을 유지합니다.
	stat_manager = StatManagerClass.new()
	# SceneTree에 추가 (SignalBus 등 연동을 위해 필요한 경우 대비)
	add_child(stat_manager)

func after_each():
	stat_manager.free()

# --------------------------------------------------------------------------
# 1. 기본 사칙연산 검증 (Arithmetic Operations)
# --------------------------------------------------------------------------

func test_apply_modifier_add():
	# Arrange (준비)
	var current_value = 10.0
	var modifier = MyStatModifier.new()
	modifier.value = 5.0
	modifier.operation = MyStatModifier.Operation.ADD
	
	# Act (실행)
	var result = stat_manager._apply_modifier(current_value, modifier)
	
	# Assert (검증)
	assert_eq(result, 15.0, "10 + 5는 15여야 합니다.")

func test_apply_modifier_multiply():
	# Arrange
	var current_value = 10.0
	var modifier = MyStatModifier.new()
	modifier.value = 2.0
	modifier.operation = MyStatModifier.Operation.MULTIPLY
	
	# Act
	var result = stat_manager._apply_modifier(current_value, modifier)
	
	# Assert
	assert_eq(result, 20.0, "10 * 2는 20이어야 합니다.")

func test_apply_modifier_divide_by_zero():
	# Arrange
	var current_value = 10.0
	var modifier = MyStatModifier.new()
	modifier.value = 0.0
	modifier.operation = MyStatModifier.Operation.DIVIDE
	
	# Act
	# 0으로 나눌 경우 에러를 내지 않고 원래 값을 반환하는지 확인 (방어 로직)
	var result = stat_manager._apply_modifier(current_value, modifier)
	
	# Assert
	assert_eq(result, 10.0, "0으로 나누기 시도 시 원래 값을 유지해야 합니다 (방어 로직).")

# --------------------------------------------------------------------------
# 2. 복합 계산 검증 (Complex Formulas)
# --------------------------------------------------------------------------

func test_calculate_mitigation():
	# 이 테스트는 방어력 수치에 따른 데미지 감소가 정확한지 검사합니다.
	# 복잡한 캐릭터 스탯 객체를 모킹(Mocking)하거나 가상으로 생성하여 테스트할 수 있습니다.
	pass

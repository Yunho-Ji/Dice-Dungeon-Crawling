extends Node

# StatManager
# 역할: 스탯 계산 공식, Modifiers 관리, 2차 스탯 파생 로직을 전담합니다.

# --------------------------------------------------------------------------
# Modifier Operations
# --------------------------------------------------------------------------
func add_modifier(stat: MyStat, value: float, operation: int, source: String = ""):
	if not stat: return
	
	var mod = MyStatModifier.new()
	mod.value = value
	mod.operation = operation
	# mod.source = source # 추후 디버깅용 소스 추가 가능
	
	stat.add_modifier(mod)
	# SignalBus를 통해 변경 알림
	SignalBus.emit_signal("stat_changed", null, stat.key, stat.computed_value)

func remove_modifier(stat: MyStat, value: float, operation: int):
	# 값을 기준으로 찾아서 지우는 것은 위험할 수 있으므로, 
	# 실제 구현 시에는 Modifier 객체 자체를 관리하거나 ID를 부여하는 것이 좋습니다.
	pass 

func clear_modifiers(stat: MyStat):
	if stat:
		stat.clear_modifiers()
		SignalBus.emit_signal("stat_changed", null, stat.key, stat.computed_value)

# --------------------------------------------------------------------------
# Core Calculation Logic (Logic Migration from MyStat/Modifier)
# --------------------------------------------------------------------------
func calculate_stat_value(stat: MyStat) -> int:
	if not stat: return 0
	
	var effective_value = stat.base_value
	
	# 향후: 여기서 Modifier 정렬 (예: Add -> Mult 순서) 로직 추가 가능
	# 현재: 리스트 순서대로 적용 (Legacy Behavior)
	for modifier in stat.modifiers:
		if modifier is MyStatModifier:
			effective_value = _apply_modifier(effective_value, modifier)
			
	return int(effective_value)

func _apply_modifier(current_value: float, modifier: MyStatModifier) -> float:
	var val = modifier.value
	match modifier.operation:
		MyStatModifier.Operation.ADD:
			return current_value + val
		MyStatModifier.Operation.SUBTRACT:
			return current_value - val
		MyStatModifier.Operation.MULTIPLY:
			return current_value * val
		MyStatModifier.Operation.DIVIDE:
			if val == 0:
				push_error("StatManager: Zero Division Error in modifier calculation")
				return current_value
			return current_value / val
		MyStatModifier.Operation.SET:
			return val
	return current_value

# --------------------------------------------------------------------------
# Derived Calculation Formulas (2차 스탯)
# --------------------------------------------------------------------------
# 예: 힘(Strength) 기반 데미지 계산
func calculate_damage(attacker_stats: MyCharacterStats, skill_multiplier: float) -> int:
	var base_atk = attacker_stats.get_stat("attack_power").computed_value
	# 여기에 치명타, 속성 보정 등 복잡한 공식을 추가합니다.
	return int(base_atk * skill_multiplier)

# 예: 방어력 기반 데미지 감소
func calculate_mitigation(damage: int, defender_stats: MyCharacterStats) -> int:
	var def = defender_stats.get_stat("defense").computed_value
	# 예시 공식: 방어력 1당 데미지 1 감소 (최소 데미지 1 보장)
	return max(1, damage - def)
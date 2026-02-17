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

func remove_modifier(stat: MyStat, modifier: MyStatModifier):
	if not stat or not modifier: return
	
	stat.remove_modifier(modifier)
	# SignalBus를 통해 변경 알림
	SignalBus.emit_signal("stat_changed", null, stat.key, stat.computed_value)

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

# [수정] 마비노기 스타일 데미지 계산 (기반 마련)
func calculate_damage(attacker_stats: MyCharacterStats, skill_multiplier: float) -> int:
	var base_atk = attacker_stats.get_stat("atk").computed_value
	
	# 향후 무기 시스템 연동 시 Min/Max/Balance 반영 예정
	# 현재는 기초 공격력을 Max로 간주하고 밸런스에 따라 하방 결정
	var max_dmg = base_atk
	var min_dmg = int(max_dmg * 0.2) # 기본 최소 데미지 20%
	var balance = 0.5 # 기본 밸런스 50%
	
	# 밸런스 로직 시뮬레이션: 밸런스가 높을수록 Max에 가까운 난수 발생
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var final_atk = max_dmg
	if rng.randf() > balance:
		final_atk = rng.randi_range(min_dmg, max_dmg)
		
	return int(final_atk * skill_multiplier)

# [수정] 방어력(Defense) 및 저항(Resistance) 기반 피해 감소
func calculate_mitigation(damage: int, defender_stats: MyCharacterStats) -> int:
	# 방어구 수치 (Defense)
	var def = defender_stats.get_stat("defense").computed_value
	# 저항 수치 (Resistance): 물리 관통 등에 대한 저항력으로 사용 가능
	
	# 예시 공식: (대미지 - 방어력) 방식 유지하되 최소 데미지 1 보장
	return max(1, damage - def)

# --------------------------------------------------------------------------
# Destiny Design Stat Mechanics (운명 설계 스탯 메커니즘)
# --------------------------------------------------------------------------

## 저항(RES) 스탯에 따른 퍼펙트 가드(PG) 범위 확장 값 계산
func calculate_pg_extension(resistance_points: int) -> float:
	var extension: float = 0.0
	
	if resistance_points <= 12:
		extension = resistance_points * 1.5
	elif resistance_points <= 25:
		extension = (12 * 1.5) + (resistance_points - 12) * 0.5
	else:
		extension = (12 * 1.5) + (13 * 0.5) + (resistance_points - 25) * 0.1
		
	return extension

## 회복력(REC) 스탯에 따른 전투 후 자동 회복 비율(%) 계산
func calculate_recovery_percentage(recovery_points: int) -> float:
	var percentage: float = 0.0
	
	if recovery_points <= 20:
		percentage = recovery_points * 0.01 # 포인트당 1%
	elif recovery_points <= 40:
		percentage = 0.20 + (recovery_points - 20) * 0.005 # 포인트당 0.5%
	else:
		percentage = 0.30 + (recovery_points - 40) * 0.002 
		
	return min(0.50, percentage)

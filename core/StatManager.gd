extends Node

# StatManager (v2.0)
# DDC 프로젝트의 모든 수치적 정의와 규칙을 관장하는 중앙 엔진입니다.
# 기획적 수치 변경은 오직 이 파일에서만 이루어져야 합니다.

# --------------------------------------------------------------------------
# 1. 수치 계산의 기초 (Modifier Logic)
# --------------------------------------------------------------------------

## 특정 스탯의 최종 연산값 산출 (기초값 + 수정자)
func calculate_stat_value(stat: MyStat) -> int:
	if not stat: return 0
	var effective_value: float = float(stat.base_value)
	
	# Modifier 적용 순서 표준화: ADD -> MULTIPLY -> SET
	# 1. ADD / SUBTRACT
	for mod in stat.modifiers:
		if mod.operation == MyStatModifier.Operation.ADD: effective_value += mod.value
		elif mod.operation == MyStatModifier.Operation.SUBTRACT: effective_value -= mod.value
	
	# 2. MULTIPLY
	for mod in stat.modifiers:
		if mod.operation == MyStatModifier.Operation.MULTIPLY: effective_value *= mod.value
	
	# 3. SET (최종 덮어쓰기)
	for mod in stat.modifiers:
		if mod.operation == MyStatModifier.Operation.SET: effective_value = mod.value
			
	return int(effective_value)

# --------------------------------------------------------------------------
# 2. 기초 스탯 기반 2차 스탯 공식 (Derived Stats Formulas)
# --------------------------------------------------------------------------

## 최대 HP (VIT 기반): 기초 100 + 건강 1당 10
func get_max_hp(stats: MyCharacterStats) -> int:
	var vit_val = stats.get_stat("vit").computed_value
	return 100 + (vit_val * 10)

## 최대 MP (INT 기반): 기초 50 + 지능 1당 5
func get_max_mp(stats: MyCharacterStats) -> int:
	var int_val = stats.get_stat("int_stat").computed_value
	return 50 + (int_val * 5)

## 초당 마나 재생 (SPI 기반): 정신 1당 0.2 (피로도 패널티 가능성 상정)
func get_mp_regen_per_sec(stats: MyCharacterStats) -> float:
	var spi_val = stats.get_stat("spi").computed_value
	var base_regen = spi_val * 0.2
	return base_regen

## 행동 게이지(AP) 충전 속도 (SPD 기반)
func get_ap_charge_speed(stats: MyCharacterStats) -> float:
	var spd_val = stats.get_stat("spd").computed_value
	# 향후 SPD가 일정 수준 이상일 때 효율이 감소하는 Diminishing Returns 적용 가능 지점
	return float(spd_val)

## 회피 확률 (AGI + 장비 기반): 민첩 1당 0.5% + 경갑 보너스
func get_evade_chance(stats: MyCharacterStats, light_armor_count: int) -> float:
	var agi_val = stats.get_stat("agi").computed_value
	var base_evade = agi_val * 0.5
	var armor_bonus = light_armor_count * 5.0
	return base_evade + armor_bonus

## 퍼펙트 가드 AP 요구량 (RES 기반): 저항 1당 요구량 0.5 감소
func get_pg_ap_threshold(stats: MyCharacterStats) -> float:
	var res_val = stats.get_stat("res").computed_value
	return max(40.0, 85.0 - (res_val * 0.5))

## 전투 후 회복 비율 계산: 회복력(REC) 기반 (신규 명명)
func get_post_battle_recovery_rate(rec_value: int) -> float:
	if rec_value <= 20: return rec_value * 0.01
	if rec_value <= 40: return 0.20 + (rec_value - 20) * 0.005
	return min(0.50, 0.30 + (rec_value - 40) * 0.002)

## [Legacy] 기존 코드 호환성 유지 (회복력 기반 회복률)
func calculate_recovery_percentage(recovery_points: int) -> float:
	return get_post_battle_recovery_rate(recovery_points)

# --------------------------------------------------------------------------
# 3. 전투 보정 및 판정 (Combat Mechanics)
# --------------------------------------------------------------------------

## 피격 시 AP 차감량 (넉백): 데미지 비례, RES로 경감
func calculate_ap_stun(damage: int, stats: MyCharacterStats) -> float:
	var res_val = stats.get_stat("res").computed_value
	var raw_stun = damage * 0.2
	var mitigation = res_val * 0.5
	return max(0.0, raw_stun - mitigation)

## 최종 피해 계산 (방어력 적용)
func calculate_final_damage(raw_damage: int, defender_stats: MyCharacterStats, p_rate: float = 0.0) -> int:
	var def_val = defender_stats.get_stat("defense").computed_value
	# 관통력 적용: 방어자의 방어력을 p_rate 비율만큼 무시
	var effective_def = int(def_val * (1.0 - p_rate))
	return max(1, raw_damage - effective_def)

# --------------------------------------------------------------------------
# 4. 데이터 연동 및 매핑 (Data Normalization)
# --------------------------------------------------------------------------

## 외부 데이터(JSON 등)의 다양한 키값을 시스템 표준 키로 변환
func normalize_stat_key(key: String) -> String:
	match key.to_lower().strip_edges():
		"hp", "max_hp", "health", "체력": return "health"
		"mp", "max_mp", "mana", "마나": return "current_mp"
		"atk", "attack", "dmg", "공격력": return "atk"
		"def", "defense", "armor", "방어력": return "defense"
		"spd", "speed", "aspd", "공격속도": return "spd"
		"agi", "dex", "민첩": return "agi"
		"vit", "con", "건강": return "vit"
		"int", "intelligence", "지능": return "int_stat"
		"res", "resistance", "저항": return "res"
		"spi", "spirit", "정신": return "spi"
		"rec", "recovery", "회복력": return "rec"
	return key

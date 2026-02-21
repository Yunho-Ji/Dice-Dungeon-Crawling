extends Node

# EnchantManager
# 역할: 주사위를 소모하여 아이템을 강화하는 로직을 담당합니다.

signal enchant_success(item_data, stats_increased)
signal enchant_failure(item_data)
signal tier_up(item_data, new_grade)

# 등급별 스텟 상한선 (Tier Caps) - Apeloot.Rarity Enum (int) 매핑
# 0: COMMON, 1: UNCOMMON, 2: RARE, 3: EPIC, 4: LEGENDARY
const TIER_CAPS = {
	0: { "atk": 20, "defense": 10, "max_hp": 100 },
	1: { "atk": 45, "defense": 25, "max_hp": 250 },
	2: { "atk": 80, "defense": 50, "max_hp": 500 },
	3: { "atk": 150, "defense": 100, "max_hp": 1000 },
	4: { "atk": 300, "defense": 200, "max_hp": 2000 }
}

# 강화 확률 (주사위 눈금에 따라 가중치 부여 가능)
const BASE_SUCCESS_CHANCE = 0.8 # 기본 80% 성공

# [핵심] 아이템 강화 함수
# target_item: 강화할 아이템 데이터 (Dictionary) - { "stats": {...}, "grade": int (Rarity) }
# dice_value: 소모된 주사위 눈금 (1~6, 1~20 등)
func enchant_item(target_item: Dictionary, dice_value: int) -> bool:
	print("EnchantManager: Enhancing item ", target_item.get("name"), " with Dice ", dice_value)
	
	# 1. 성공 여부 판정 (주사위 값이 높을수록 확률 보정? 기획에 따라 조정 가능)
	# 현재는 n% 확률 (기본 80%)
	if randf() > BASE_SUCCESS_CHANCE:
		print("EnchantManager: 강화 실패!")
		emit_signal("enchant_failure", target_item)
		return false

	# 2. 스탯 증가량 계산 (주사위 값의 n% 가중)
	# 예: 주사위 6 -> 공격력 +3 (50%), 주사위 1 -> 공격력 +1
	var stat_increase = int(ceil(dice_value * 0.5)) # 절반 올림
	
	# 3. 아이템의 주요 스탯 찾기 (가장 높은 스탯 혹은 첫 번째 스탯)
	var stats = target_item.get("stats", {})
	if stats.is_empty():
		print("EnchantManager: 강화할 스탯이 없습니다.")
		return false
		
	var target_stat_key = stats.keys()[0] # 단순하게 첫 번째 스탯 선택 (추후 UI 선택 가능)
	var current_val = stats[target_stat_key]
	
	# 값 증가
	stats[target_stat_key] = current_val + stat_increase
	print("EnchantManager: ", target_stat_key, " increased by ", stat_increase, " (New: ", stats[target_stat_key], ")")
	
	emit_signal("enchant_success", target_item, {target_stat_key: stat_increase})
	
	# 4. 등급 승급(Tier Up) 체크
	_check_tier_up(target_item, target_stat_key)
	
	return true

func _check_tier_up(item: Dictionary, stat_key: String):
	var current_grade = item.get("grade", 0) # int (Apeloot.Rarity)
	if current_grade >= 4: return # LEGENDARY (4) 이상은 승급 불가
	
	var caps = TIER_CAPS.get(current_grade, {})
	var cap_value = caps.get(stat_key, 99999) # 캡이 없으면 무제한
	
	var current_val = item["stats"][stat_key]
	
	if current_val > cap_value:
		# 캡 돌파! 등급 상승
		var next_grade = current_grade + 1
		print("EnchantManager: TIER UP! ", current_grade, " -> ", next_grade)
		
		# 등급 변경
		item["grade"] = next_grade
		
		# 4-1. 수치 재설정 (임의로 재설정 로직)
		# 기획: "다음 등급으로 수치가 임의로 재설정된다."
		# 구현: 캡 + 주사위 보너스 정도로 재설정하거나, 해당 등급의 최소치로 설정
		# 여기서는 '캡 값 + 알파'로 유지하되, 약간의 랜덤성을 부여하겠습니다.
		var new_base = cap_value + randi_range(1, 5)
		item["stats"][stat_key] = new_base
		
		# 이름 색상 변경 등은 UI에서 처리 (grade 데이터 기반)
		emit_signal("tier_up", item, next_grade)

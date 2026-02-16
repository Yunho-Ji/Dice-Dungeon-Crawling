extends "res://addons/gut/test.gd"

# 전투 및 방어구 매커니즘 테스트
# 목표: 정수형 계산 정확도, 방어구 유형별 시너지, 저항력에 따른 AP 넉백 검증

var CharacterClass = load("res://characters/Character.gd")
var character: Character = null

func before_each():
	# 캐릭터 인스턴스 생성 및 초기화
	character = CharacterClass.new()
	# UI 관련 노드(ProgressBar 등)가 없으므로 더미 노드를 추가하여 에러 방지
	var pb = ProgressBar.new()
	pb.name = "ProgressBar"
	character.add_child(pb)
	var lb = Label.new()
	lb.name = "Label"
	character.add_child(lb)
	
	# 기본 스탯 설정 (Novice 데이터 기반)
	var stats = MyCharacterStats.new()
	stats.health.base_value = 100
	stats.health.current_value = 100
	stats.attack_power.base_value = 10
	stats.defense.base_value = 0
	stats.current_mp.base_value = 50
	stats.current_mp.current_value = 50
	stats.resistance.base_value = 0
	stats.agility.base_value = 0
	
	character.current_stats = stats
	character.cloth_pieces = 0
	character.light_pieces = 0
	character.heavy_pieces = 0

func after_each():
	character.free()

# 1. 중갑(Heavy) 테스트: DR% 및 저항 효율
func test_heavy_armor_mechanics():
	character.heavy_pieces = 4 # 4피스 착용 시 DR 20%, 저항 효율 1.5배
	character.current_stats.resistance.base_value = 100 # 기본 저항 100 -> 최종 150
	
	# 100 데미지 피격
	# DR 20% 적용 -> 80 데미지
	# AP 넉백 계산: (80 * 0.5) * (100 / (100 + 150)) = 40 * 0.4 = 16
	character.action_gauge = 100.0
	character.take_damage(100)
	
	assert_eq(character.current_stats.health.current_value, 20, "HP는 100 - 80 = 20이어야 함")
	assert_eq(int(character.action_gauge), 84, "AP 넉백은 16이어야 함 (100 - 16 = 84)")

# 2. 천(Cloth) 테스트: 마나 실드 및 취약 상태
func test_cloth_armor_mechanics():
	character.cloth_pieces = 4 # 4피스 착용 시 데미지 60% 흡수
	character.current_stats.current_mp.current_value = 100
	
	# 100 데미지 피격
	# processed_damage = 100
	# absorb_rate = 0.6 -> absorb_damage = 60
	# mp_cost = 60 / 2 = 30
	# final_hp_damage = 100 - 60 = 40
	character.take_damage(100)
	
	assert_eq(character.current_stats.health.current_value, 60, "HP는 100 - 40 = 60이어야 함")
	assert_eq(character.current_stats.current_mp.current_value, 70, "MP는 100 - 30 = 70이어야 함")
	
	# 실드 브레이크 테스트
	# 현재 MP 70 -> 최대 흡수량 140
	# 300 데미지 피격 시 (흡수 필요량 180 > 가용량 140) -> 실드 브레이크 발생
	character.take_damage(300)
	assert_true(character.is_vulnerable, "MP 부족으로 실드 브레이크 및 취약 상태가 되어야 함")
	assert_eq(character.current_stats.current_mp.current_value, 0, "MP는 0이 되어야 함")

# 3. 경갑(Light) 테스트: 빗겨맞음 (민첩 기반)
func test_light_armor_glance():
	character.current_stats.agility.base_value = 200 # 빗겨맞음 확률 100% (민첩 * 0.5)
	
	# 100 데미지 피격 -> 빗겨맞음으로 50 데미지 적용
	character.take_damage(100)
	
	assert_eq(character.current_stats.health.current_value, 50, "빗겨맞음으로 데미지가 50% 감소해야 함")

# 4. 정수형 계산 무결성 테스트
func test_integer_integrity():
	character.cloth_pieces = 1 # 15% 흡수
	# 11 데미지 피격
	# absorb_damage = int(11 * 0.15) = int(1.65) = 1
	# mp_cost = ceil(1 / 2.0) = 1
	# final_hp_damage = 11 - 1 = 10
	character.take_damage(11)
	
	assert_eq(character.current_stats.health.current_value, 90, "데미지는 정확히 10이어야 함")
	assert_eq(character.current_stats.current_mp.current_value, 49, "MP 소모는 정확히 1이어야 함")

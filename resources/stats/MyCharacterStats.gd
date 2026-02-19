# MyCharacterStats.gd
# DDC 8유형 스탯 시스템 리디자인
extends Resource
class_name MyCharacterStats

# 1. 기반 및 방어구 요구 스탯
@export var agi: MyIntStat = MyIntStat.new() # 민첩 (AGI): 경갑 요구치 / 회피
@export var vit: MyIntStat = MyIntStat.new() # 건강 (VIT): 중갑 요구치 / 최대 HP
@export var int_stat: MyIntStat = MyIntStat.new() # 지능 (INT): 천옷 요구치 / 최대 MP

# 2. 전투 실무 및 화력 스탯
@export var atk: MyIntStat = MyIntStat.new() # 공격력 (ATK): 기초 공격력
@export var spd: MyIntStat = MyIntStat.new() # 공격속도 (SPD): AP(행동 게이지) 속도

# 3. 유지력 및 주도권 스탯
@export var res: MyIntStat = MyIntStat.new() # 저항 (RES): 물리 저항 / AP 차감 저항
@export var spi: MyIntStat = MyIntStat.new() # 정신 (SPI): 정신 저항 / MP 재생 / 주사위 자원
@export var rec: MyIntStat = MyIntStat.new() # 회복력 (REC): HP 재생 / 포션 효율

# --- 파생 및 특수 수치 (내부 참조용) ---
@export var health: MyIntStat = MyIntStat.new()
@export var current_mp: MyIntStat = MyIntStat.new()
@export var defense: MyIntStat = MyIntStat.new() # 방어구 합산용

func _init():
	_setup_keys()
	# [신규] 건강(VIT)과 지능(INT) 변화 시 파생 스탯(HP/MP) 자동 업데이트 연결
	vit.value_changed.connect(func(_val): update_derived_stats())
	int_stat.value_changed.connect(func(_val): update_derived_stats())

func _setup_keys():
	agi.key = "agi"
	vit.key = "vit"
	int_stat.key = "int_stat"
	atk.key = "atk"
	spd.key = "spd"
	res.key = "res"
	spi.key = "spi"
	rec.key = "rec"
	health.key = "health"
	current_mp.key = "current_mp"
	defense.key = "defense"

# VIT/INT에 따른 HP/MP 업데이트 로직
func update_derived_stats():
	if not StatManager: return
	
	# StatManager 중앙 공식을 통해 파생 수치 결정
	health.base_value = StatManager.get_max_hp(self)
	current_mp.base_value = StatManager.get_max_mp(self)
	
	# 초기화 시점(현재값이 0일 때) 혹은 최대치를 초과했을 때 보정
	if health.current_value == 0 or health.current_value > health.base_value:
		health.current_value = health.base_value
	if current_mp.current_value == 0 or current_mp.current_value > current_mp.base_value:
		current_mp.current_value = current_mp.base_value
	
	# UI 갱신을 위해 시그널 발생
	health.emit_signal("value_changed", health.computed_value)
	current_mp.emit_signal("value_changed", current_mp.computed_value)

func get_stat(key: String) -> MyStat:
	match key.to_lower():
		"agi": return agi
		"vit": return vit
		"int", "int_stat": return int_stat
		"atk", "attack_power": return atk
		"spd", "attack_speed": return spd
		"res", "resistance": return res
		"spi", "spirit": return spi
		"rec", "recovery_power": return rec
		"health": return health
		"current_mp": return current_mp
		"defense": return defense
	return null

func get_all_stats() -> Array:
	return [agi, vit, int_stat, atk, spd, res, spi, rec, health, current_mp]

func get_all_stat_keys() -> Array:
	return ["agi", "vit", "int_stat", "atk", "spd", "res", "spi", "rec"]

func clone() -> MyCharacterStats:
	var new_instance = MyCharacterStats.new()
	new_instance.agi = agi.clone()
	new_instance.vit = vit.clone()
	new_instance.int_stat = int_stat.clone()
	new_instance.atk = atk.clone()
	new_instance.spd = spd.clone()
	new_instance.res = res.clone()
	new_instance.spi = spi.clone()
	new_instance.rec = rec.clone()
	new_instance.update_derived_stats()
	return new_instance

# 다른 stats 객체로부터 값을 동기화
func sync_from(other: MyCharacterStats):
	if not other: return
	
	# 각 스탯 객체의 sync_from을 호출하여 base_value 및 modifiers 전체 동기화
	agi.sync_from(other.agi)
	vit.sync_from(other.vit)
	int_stat.sync_from(other.int_stat)
	atk.sync_from(other.atk)
	spd.sync_from(other.spd)
	res.sync_from(other.res)
	spi.sync_from(other.spi)
	rec.sync_from(other.rec)
	
	# 파생 스탯 업데이트 (Modifier 반영 후 재계산)
	update_derived_stats()
	
	# [신규] 방어력(Defense) 등 별도 관리 스탯도 동기화 필요 시 추가
	if defense and other.defense:
		defense.sync_from(other.defense)

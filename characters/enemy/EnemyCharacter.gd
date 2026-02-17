class_name EnemyCharacter
extends "res://characters/Character.gd"

@export var base_max_hp: int = 50
@export var hp_per_level: int = 8
@export var base_attack_power: int = 5
@export var attack_power_per_level: int = 1
@export var base_defense: int = 0
@export var defense_per_level: int = 1
@export var base_attack_speed: float = 80.0

# 보스 관련 스탯 (선택 사항: GameManager에서 관리할 수도 있음)
@export var is_boss: bool = false
@export var boss_hp_multiplier: float = 2.0
@export var boss_attack_multiplier: float = 1.5
@export var boss_defense_multiplier: float = 2.0

# 적의 레벨에 따라 능력치를 설정하는 함수입니다.
func set_level(stage: int, battle_count: int, p_hp_multiplier: float = 1.0):
	if not current_stats:
		printerr("ERROR: EnemyCharacter: current_stats is null.")
		return

	# 스테이지와 전투 횟수를 기반으로 유효 레벨을 계산합니다.
	var effective_level = (stage - 1) * 5 + battle_count

	# [수정] 새로운 8유형 스탯 키를 사용하여 스케일링 적용
	
	# 건강 (VIT): 레벨당 1씩 증가 (체력으로 자동 환산됨)
	var vit_stat = current_stats.get_stat("vit")
	if vit_stat:
		var base_vit = vit_stat.base_value
		vit_stat.base_value = int((base_vit + effective_level) * p_hp_multiplier)
	
	# 공격력 (ATK): 레벨당 1씩 증가
	var atk_stat = current_stats.get_stat("atk")
	if atk_stat:
		var base_atk = atk_stat.base_value
		atk_stat.base_value = base_atk + effective_level
		
	# 공격속도 (SPD): 레벨당 2씩 증가
	var spd_stat = current_stats.get_stat("spd")
	if spd_stat:
		var base_spd = spd_stat.base_value
		spd_stat.base_value = base_spd + (effective_level * 2)

	# 저항 (RES): 3레벨당 1씩 증가
	var res_stat = current_stats.get_stat("res")
	if res_stat:
		var base_res = res_stat.base_value
		res_stat.base_value = base_res + int(effective_level / 3.0)

	# [핵심] 스탯 변경 후 파생 수치(HP/MP) 강제 업데이트 및 완전 회복
	current_stats.update_derived_stats()
	
	var hp_stat = current_stats.get_stat("health")
	if hp_stat:
		hp_stat.current_value = hp_stat.computed_value
	
	update_hp_label() # UI 갱신

	# 디버그 출력
	print("Enemy Scaled (Lvl ", effective_level, "): HP:", hp_stat.computed_value if hp_stat else 0, 
		", ATK:", atk_stat.computed_value if atk_stat else 0, 
		", SPD:", spd_stat.computed_value if spd_stat else 0)

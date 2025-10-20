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
	# 스테이지와 전투 횟수를 기반으로 유효 레벨을 계산합니다.
	var effective_level = (stage - 1) * 5 + battle_count

	# 기본 능력치를 레벨에 맞게 설정합니다.
	var calculated_max_hp = base_max_hp + effective_level * hp_per_level
	stats_manager.get_stat("health").base_value = int(calculated_max_hp * p_hp_multiplier) # Apply multiplier from GameManager
	stats_manager.get_stat("attack_power").base_value = base_attack_power + effective_level * attack_power_per_level
	stats_manager.get_stat("defense").base_value = base_defense + effective_level * defense_per_level
	stats_manager.get_stat("attack_speed").base_value = base_attack_speed

	# 보스일 경우, 추가적인 스탯 조정을 할 수 있습니다 (예: 공격 속도).
	if is_boss:
		stats_manager.get_stat("attack_speed").base_value = 100.0 # 보스 공격 속도는 고정값으로 설정합니다.

	# 현재 HP를 최대 HP와 동일하게 설정하여 완전히 회복된 상태로 만듭니다。
	stats_manager.get_stat("health").base_value = stats_manager.get_stat("health").computed_value
	update_hp_label() # HP 라벨 UI를 업데이트합니다。

	print("적 스탯 설정됨 (스테이지 ", stage, "-", battle_count, "): HP:", stats_manager.get_stat("health").computed_value, ", 공격:", stats_manager.get_stat("attack_power").computed_value, ", 방어:", stats_manager.get_stat("defense").computed_value, ", 속도:", stats_manager.get_stat("attack_speed").computed_value)



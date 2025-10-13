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

func _ready():
	super._ready()
	# 초기 스탯 설정은 GameManager에서 set_level()을 호출하여 처리합니다.

func set_level(stage: int, battle_count: int):
	# 기본 스탯 계산
	# 스테이지와 전투 횟수를 모두 고려하여 난이도 곡선 설계
	var effective_level = (stage - 1) * 5 + battle_count # 예: 1-1은 레벨 1, 2-1은 레벨 6

	max_hp = base_max_hp + effective_level * hp_per_level
	attack_power = base_attack_power + effective_level * attack_power_per_level
	defense = base_defense + effective_level * defense_per_level
	attack_speed = base_attack_speed

	# 보스인 경우 스탯 배율 적용
	if is_boss:
		max_hp = int(max_hp * boss_hp_multiplier)
		attack_power = int(attack_power * boss_attack_multiplier)
		defense = int(defense * boss_defense_multiplier)
		attack_speed = 100.0 # 보스 공격 속도 (고정 또는 별도 설정)

	current_hp = max_hp # 레벨 설정 시 현재 HP를 최대 HP로 초기화
	update_hp_label() # HP 라벨 업데이트

	print("적 스탯 설정됨 (스테이지 ", stage, "-", battle_count, "): HP:", max_hp, ", 공격:", attack_power, ", 방어:", defense, ", 속도:", attack_speed)

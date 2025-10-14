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

# Enemy's actual stats (managed by this instance)
var max_hp: int
var current_hp: int
var attack_power: int
var defense: int
var attack_speed: float
var recovery_power: int
var max_mp: int
var current_mp: int
var luck: int
var resistance: int

func _ready():
	super._ready()
	# 초기 스탯 설정은 GameManager에서 set_level()을 호출하여 처리합니다.

func set_level(stage: int, battle_count: int):
	# 기본 스탯 계산
	# 스테이지와 전투 횟수를 모두 고려하여 난이도 곡선 설계
	var effective_level = (stage - 1) * 5 + battle_count # 예: 1-1은 레벨 1, 2-1은 레벨 6

	set_max_hp(base_max_hp + effective_level * hp_per_level)
	set_attack_power(base_attack_power + effective_level * attack_power_per_level)
	set_defense(base_defense + effective_level * defense_per_level)
	set_attack_speed(base_attack_speed)

	# 보스인 경우 스탯 배율 적용
	if is_boss:
		set_max_hp(int(get_max_hp() * boss_hp_multiplier))
		set_attack_power(int(get_attack_power() * boss_attack_multiplier))
		set_defense(int(get_defense() * boss_defense_multiplier))
		set_attack_speed(100.0) # 보스 공격 속도 (고정 또는 별도 설정)

	set_current_hp(get_max_hp()) # 레벨 설정 시 현재 HP를 최대 HP로 초기화
	update_hp_label() # HP 라벨 업데이트

	print("적 스탯 설정됨 (스테이지 ", stage, "-", battle_count, "): HP:", get_max_hp(), ", 공격:", get_attack_power(), ", 방어:", get_defense(), ", 속도:", get_attack_speed())

# Stat Getters/Setters (override Character's virtual methods)
func get_max_hp() -> int: return max_hp
func set_max_hp(value: int): max_hp = value
func get_current_hp() -> int: return current_hp
func set_current_hp(value: int): current_hp = value
func get_attack_power() -> int: return attack_power
func set_attack_power(value: int): attack_power = value
func get_defense() -> int: return defense
func set_defense(value: int): defense = value
func get_attack_speed() -> float: return attack_speed
func set_attack_speed(value: float): attack_speed = value
func get_recovery_power() -> int: return recovery_power
func set_recovery_power(value: int): recovery_power = value
func get_max_mp() -> int: return max_mp
func set_max_mp(value: int): max_mp = value
func get_current_mp() -> int: return current_mp
func set_current_mp(value: int): current_mp = value
func get_luck() -> int: return luck
func set_luck(value: int): luck = value
func get_resistance() -> int: return resistance
func set_resistance(value: int): resistance = value

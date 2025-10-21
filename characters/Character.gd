class_name Character
extends CharacterBody2D

signal damage_taken(amount: int, position: Vector2)

enum Stance { ATTACK, DEFENSE, EVADE }

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false
var current_stance: Stance = Stance.ATTACK # 현재 스탠스
var active_status_effects: Array[StatusEffect] = [] # 활성 상태 효과 (버프, 디버프, DOT 등)

const BuffA_Data = preload("res://resources/status_effects/data/BuffA_Data.tres")
const GuardBuff_Data = preload("res://resources/status_effects/data/GuardBuff_Data.tres")
const PerfectGuardBuff_Data = preload("res://resources/status_effects/data/PerfectGuardBuff_Data.tres")

func set_stance(new_stance: Stance):
	current_stance = new_stance
	print(name, " 스탠스 변경: ", Stance.keys()[current_stance])

func add_status_effect(effect_data: StatusEffectData, duration_override: float = -1.0):
	var new_effect = StatusEffect.new()
	new_effect.data = effect_data
	if duration_override > 0:
		new_effect.data.duration = duration_override

	# 이미 같은 이름의 효과가 있는지 확인 (중복 방지 또는 갱신 로직)
	for i in range(active_status_effects.size()):
		if active_status_effects[i].get_effect_name() == new_effect.get_effect_name():
			# 기존 효과 갱신 또는 무시 (여기서는 갱신)
			active_status_effects[i].remove_effect(self)
			active_status_effects.erase(active_status_effects[i])
			break

	new_effect._time_remaining = new_effect.data.duration # 지속 시간 초기화
	active_status_effects.append(new_effect)
	new_effect.apply_effect(self)
	print(name, "에게 상태 효과 적용: ", new_effect.get_effect_name())

func remove_status_effect(effect: StatusEffect):
	if active_status_effects.has(effect):
		effect.remove_effect(self)
		active_status_effects.erase(effect)
		print(name, "에게서 상태 효과 제거: ", effect.get_effect_name())

@onready var stats_manager: MyStatsManager = $MyStatsManager # Reference to the new stat manager


@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label

func _ready():
	print("DEBUG: Character.gd: _ready called for ", name) # New line
	set_process(false)
	input_pickable = true
	action_gauge = 0.0
	# Stat initialization will be handled by GameManager calling set_stats()
	# update_hp_label() will be called by set_stats()
	connect("input_event", Callable(self, "_on_input_event"))
	action_gauge_bar.position = Vector2(-32, -45)
	hp_label.position = Vector2(-32, 20)

func _process(delta: float):
	if stats_manager.get_stat("health").computed_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	if target == null or not is_instance_valid(target) or target.stats_manager.get_stat("health").computed_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return

	# 상태 효과 지속 시간 업데이트 및 만료된 효과 제거
	var effects_to_remove = []
	for effect in active_status_effects:
		if not effect.update_duration(delta):
			effects_to_remove.append(effect)
	for effect in effects_to_remove:
		remove_status_effect(effect)

	action_gauge += stats_manager.get_stat("attack_speed").computed_value * delta
	action_gauge_bar.value = action_gauge

	if action_gauge >= 100.0:
		perform_stance_action()
		action_gauge = 0.0 # 행동 후 게이지 초기화

func perform_stance_action():
	match current_stance:
		Stance.ATTACK:
			perform_attack_action()
		Stance.DEFENSE:
			perform_defense_action(action_gauge)
		Stance.EVADE:
			perform_evade_action(action_gauge)

func perform_attack_action():
	if target and is_instance_valid(target):
		#print(name, "가 ", target.name, "에게 공격합니다! 공격력: ", stats_manager.get_stat("attack_power").computed_value)
		attack(target) # 기존 attack 함수 호출
	else:
		print(name, " 공격할 대상이 없습니다.")

func perform_defense_action(action_gauge_value: float):
	print(name, " 방어 행동 시작 (게이지: ", action_gauge_value, "%)")
	var gauge_percentage = action_gauge_value

	if gauge_percentage < 40.0:
		print(name, " 방어 실패 (게이지 부족)")
	elif gauge_percentage < 85.0:
		print(name, " 가드 성공!")
		add_status_effect(GuardBuff_Data) # 가드 버프 적용
		# 액션 게이지 20% 리턴
		action_gauge += 20.0
	else: # 85.0 이상
		print(name, " 퍼펙트 가드 성공!")
		add_status_effect(PerfectGuardBuff_Data) # 퍼펙트 가드 버프 적용
		# TODO: 퍼펙트 가드 효과 구현 (예: 받는 피해 대폭 감소 및 반격 기회)
		# 액션 게이지 40% 리턴
		action_gauge += 40.0
	action_gauge_bar.value = action_gauge # 게이지 업데이트

func perform_evade_action(action_gauge_value: float):
	print(name, " 회피 행동 시작 (게이지: ", action_gauge_value, "%)")
	var gauge_percentage = action_gauge_value
	var success_chance: float = 0.0
	var buff_duration: float = 0.0 # 버프 지속 시간

	if gauge_percentage < 60.0:
		print(name, " 긴급 회피 시도...")
		success_chance = 60.0
		buff_duration = 3.0 # 짧은 버프 A 지속 시간
	else: # 60.0 이상
		print(name, " 회피 시도...")
		success_chance = 80.0
		buff_duration = 6.0 # 긴 버프 A 지속 시간

	if randf() * 100.0 < success_chance:
		print(name, " 회피 성공! 버프 A 획득 (", buff_duration, "초)")
		add_status_effect(BuffA_Data, buff_duration) # BuffA 데이터와 지속 시간 오버라이드
	else:
		print(name, " 회피 실패!")

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	var final_damage = max(0, amount - stats_manager.get_stat("defense").computed_value)
	stats_manager.get_stat("health").base_value -= final_damage # Direct modification of base_value
	stats_manager.get_stat("health").base_value = max(0, stats_manager.get_stat("health").computed_value) # Ensure HP doesn't go below 0

	update_hp_label()
	emit_signal("damage_taken", final_damage, global_position) # Emit signal
	#print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", stats_manager.get_stat("health").computed_value)
	if stats_manager.get_stat("health").computed_value <= 0:
		print(name, " 사망!")
		set_process(false)

func update_hp_label():
	hp_label.text = "HP: " + str(stats_manager.get_stat("health").computed_value) + "/" + str(stats_manager.get_stat("health").base_value)

func attack(target_node: CharacterBody2D):
	#print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", stats_manager.get_stat("attack_power").computed_value)
	target_node.take_damage(stats_manager.get_stat("attack_power").computed_value)

func reset_for_next_battle():
	action_gauge = 0.0
	if action_gauge_bar:
		action_gauge_bar.value = 0.0
	print(name, "의 행동 게이지가 초기화되었습니다.")

func apply_dice_to_stat(stat_name: String, value: int):
	var stat = stats_manager.get_stat(stat_name)
	if stat:
		stat.base_value += value # Direct modification of base_value
		print(stat_name, "에 ", value, " 추가. 현재 값: ", stat.computed_value)
	else:
		print("알 수 없는 스탯: ", stat_name)

	if ui_manager and ui_manager.has_method("update_player_stats_ui"):
		ui_manager.update_player_stats_ui(stats_manager) # Pass stats_manager

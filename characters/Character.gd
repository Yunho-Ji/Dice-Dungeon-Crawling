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
var character_data: CharacterData # 캐릭터의 기본 데이터를 담을 변수
var _stat_signals_connected: bool = false # 스탯 신호 연결 여부 플래그

func initialize(data: CharacterData):
	self.character_data = data
	# 중요: 리소스 공유 문제를 피하기 위해 스탯 리소스를 복제합니다.
	print("DEBUG: Character.gd: Initializing with CharacterData: ", data.character_name)
	
	if data and data.base_stats:
		stats_manager.character_stats = data.base_stats.duplicate(true)
		print("DEBUG: Character.gd: Stats initialized from CharacterData.")
	else:
		printerr("ERROR: Character.gd: Invalid CharacterData or base_stats provided for initialization.")

	# 초기화 후 스탯 라벨 업데이트 등 필요한 작업 수행
	update_hp_label()

#const BuffA_Data = preload("res://resources/status_effects/data/BuffA_Data.tres")



func set_stance(new_stance: Stance):
	current_stance = new_stance
	print(name, " 스탠스 변경: ", Stance.keys()[current_stance])
	
	# 방어는 선불 비용만 있으면 언제든 즉시 발동 (긴급 방어)
	if new_stance == Stance.DEFENSE and action_gauge >= 15.0:
		perform_stance_action()
	# 그 외 행동은 게이지 100%일 때만 발동
	elif action_gauge >= 100.0:
		perform_stance_action()

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

	# 방어 태세 중에는 행동 게이지가 차오르지 않음 (유지)
	if current_stance != Stance.DEFENSE:
		action_gauge += stats_manager.get_stat("attack_speed").computed_value * delta
	
	action_gauge_bar.value = action_gauge

	# 공격/회피 스탠스일 때만 100% 도달 시 자동 행동 (방어는 유저가 선택한 시점에 이미 perform_defense_action 호출됨)
	if current_stance != Stance.DEFENSE and action_gauge >= 100.0:
		perform_stance_action()

func perform_stance_action():
	match current_stance:
		Stance.ATTACK:
			perform_attack_action()
		Stance.DEFENSE:
			perform_defense_action()
		Stance.EVADE:
			perform_evade_action()

func perform_attack_action():
	if target and is_instance_valid(target):
		attack(target)
	else:
		print(name, " 공격할 대상이 없습니다.")
	
	# 공격은 항상 게이지 전체 소모
	action_gauge = 0.0
	action_gauge_bar.value = action_gauge

var is_guarding: bool = false
var is_perfect_guarding: bool = false

func perform_defense_action():
	# 선불제 방어: 즉시 비용 지불하고 태세 돌입
	var upfront_cost = 15.0
	action_gauge = max(0.0, action_gauge - upfront_cost)
	is_guarding = true
	is_perfect_guarding = false 
	
	print(name, " 방어 태세 돌입! (선불 비용: ", upfront_cost, ", 잔여 게이지: ", action_gauge, "%)")
	action_gauge_bar.value = action_gauge # UI 즉시 갱신

const STATPOWDEBUFF_Data = preload("res://resources/status_effects/data/STATPOWDEBUFF_Data.tres")

func perform_evade_action():
	print(name, " 회피 행동 시작 (게이지: ", action_gauge, "%)")
	var gauge_percentage = action_gauge
	var success_chance: float = 0.0
	var buff_duration: float = 0.0
	var consumption = 100.0

	if gauge_percentage < 60.0:
		print(name, " 긴급 회피 시도...")
		success_chance = 60.0
		buff_duration = 3.0
	else:
		print(name, " 회피 시도...")
		success_chance = 80.0
		buff_duration = 6.0

	if randf() * 100.0 < success_chance:
		print(name, " 회피 성공! 버프 획득")
		add_status_effect(STATPOWDEBUFF_Data, buff_duration)
		consumption = 70.0 # 회피 성공 시 30% 보존
	else:
		print(name, " 회피 실패!")
		consumption = 100.0
		
	action_gauge = max(0.0, action_gauge - consumption)
	action_gauge_bar.value = action_gauge

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	print("DEBUG: take_damage called. Amount: ", amount, ", is_guarding: ", is_guarding)
	var damage_reduction = 0.0
	var retained_gauge = 0.0 
	
	if is_guarding:
		print(name, " [방어 판정 진입] 현재 게이지: ", action_gauge, "%")
		if action_gauge >= 85.0:
			print(name, " >>> 퍼펙트 가드 성공! <<<")
			damage_reduction = 0.9
			retained_gauge = 50.0
			is_perfect_guarding = true 
		elif action_gauge >= 40.0:
			print(name, " 가드 성공!")
			damage_reduction = 0.3
			retained_gauge = 20.0
		else:
			print(name, " 가드 브레이크! (게이지 부족)")
			damage_reduction = 0.0
			retained_gauge = 0.0
		
		# 피격 후 방어 태세 해제 및 보상 게이지 적용
		is_guarding = false
		current_stance = Stance.ATTACK 
		print(name, " 방어 해제 완료. Stance: ", Stance.keys()[current_stance], ", Next Gauge: ", retained_gauge)
		
		action_gauge = retained_gauge
		action_gauge_bar.value = action_gauge # UI 즉시 갱신

	var final_damage = max(0, amount - stats_manager.get_stat("defense").computed_value)
	final_damage = int(final_damage * (1.0 - damage_reduction))

	stats_manager.get_stat("health").current_value -= final_damage
	stats_manager.get_stat("health").current_value = max(0, stats_manager.get_stat("health").current_value)

	update_hp_label()
	emit_signal("damage_taken", final_damage, global_position)
	
	print(name, "가 ", final_damage, " 대미지를 받았습니다. 남은 HP: ", stats_manager.get_stat("health").current_value)

	if stats_manager.get_stat("health").current_value <= 0:
		print(name, " 사망!")
		set_process(false)


func update_hp_label():
	print("DEBUG: update_hp_label called by signal system!")
	hp_label.text = "HP: " + str(stats_manager.get_stat("health").current_value) + "/" + str(stats_manager.get_stat("health").computed_value)

func attack(target_node: CharacterBody2D):
	#print(name, "가 ", target_node.name, "에게 공격합니다! 공격력: ", stats_manager.get_stat("attack_power").computed_value)
	target_node.take_damage(stats_manager.get_stat("attack_power").computed_value)


func update_stats_from_player_manager(player_mgr: PlayerManager):
	if player_mgr and player_mgr.current_player_stats:
		# Synchronize the character's local stats with the PlayerManager's session stats.
		stats_manager.character_stats.sync_from(player_mgr.current_player_stats)

		print("DEBUG: Character.gd: Stats updated from PlayerManager.current_player_stats for ", name)
		
		# Connect stat signals for real-time UI updates, only once.
		if not _stat_signals_connected:
			for stat in stats_manager.get_all_stats():
				if stat and not stat.value_changed.is_connected(update_hp_label):
					stat.value_changed.connect(update_hp_label)
			_stat_signals_connected = true
			print("DEBUG: Character.gd: Stat signals connected for real-time updates.")

		update_hp_label() # Refresh HP display
	else:
		printerr("ERROR: Character.gd: PlayerManager or current_player_stats not valid for updating stats.")

func set_level(p_stage: int, p_battle_count: int, hp_multiplier: float):
	print("DEBUG: set_level function called for '", name, "'")
	# TODO: This clears ALL modifiers. A more robust system would identify and
	# remove only the modifiers from a previous set_level call.
	for stat_key in stats_manager.character_stats.get_all_stat_keys():
		var stat = stats_manager.get_stat(stat_key)
		if stat:
			stat.clear_modifiers()

	# Health scaling
	var health_stat = stats_manager.get_stat("health")
	if health_stat:
		var hp_bonus = int(health_stat.base_value * (hp_multiplier - 1.0))
		var health_modifier = MyStatModifier.new()
		health_modifier.operation = MyStatModifier.Operation.ADD
		health_modifier.value = hp_bonus
		health_stat.add_modifier(health_modifier)
		
		# After scaling, reset current HP to the new max HP
		health_stat.current_value = health_stat.computed_value

	# Attack scaling
	var attack_stat = stats_manager.get_stat("attack_power")
	if attack_stat:
		var attack_modifier = MyStatModifier.new()
		attack_modifier.operation = MyStatModifier.Operation.ADD
		attack_modifier.value = p_stage # This is probably too low, but we're fixing the architecture
		attack_stat.add_modifier(attack_modifier)
		attack_stat.current_value = attack_stat.computed_value

	# Defense scaling
	var defense_stat = stats_manager.get_stat("defense")
	if defense_stat:
		var defense_modifier = MyStatModifier.new()
		defense_modifier.operation = MyStatModifier.Operation.ADD
		defense_modifier.value = p_battle_count # Also probably too low
		defense_stat.add_modifier(defense_modifier)
	update_hp_label()

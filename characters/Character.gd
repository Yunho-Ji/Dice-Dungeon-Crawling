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

var is_guarding: bool = false
var is_perfect_guarding: bool = false

func perform_defense_action(action_gauge_value: float):
	print(name, " 방어 행동 시작 (게이지: ", action_gauge_value, "%)")
	var gauge_percentage = action_gauge_value

	if gauge_percentage < 40.0:
		print(name, " 방어 실패 (게이지 부족)")
	elif gauge_percentage < 85.0:
		print(name, " 가드 성공!")
		is_guarding = true
		# 액션 게이지 20% 리턴
		action_gauge += 20.0
	else: # 85.0 이상
		print(name, " 퍼펙트 가드 성공!")
		is_perfect_guarding = true
		# TODO: 퍼펙트 가드 효과 구현 (예: 받는 피해 대폭 감소 및 반격 기회)
		# 액션 게이지 40% 리턴
		action_gauge += 40.0
	action_gauge_bar.value = action_gauge # 게이지 업데이트

const STATPOWDEBUFF_Data = preload("res://resources/status_effects/data/STATPOWDEBUFF_Data.tres")

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
		add_status_effect(STATPOWDEBUFF_Data, buff_duration) # BuffA 데이터와 지속 시간 오버라이드
	else:
		print(name, " 회피 실패!")

func _on_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int):
	pass
	

func take_damage(amount: int):
	var damage_reduction = 0.0
	if is_perfect_guarding:
		print(name, " 퍼펙트 가드로 공격을 막았습니다!")
		damage_reduction = 0.9
		is_perfect_guarding = false
		is_guarding = false # 퍼펙트 가드 시 일반 가드도 해제
	elif is_guarding:
		print(name, " 가드로 피해를 30% 감소시킵니다!")
		damage_reduction = 0.3
		is_guarding = false

	var final_damage = max(0, amount - stats_manager.get_stat("defense").computed_value)
	final_damage = int(final_damage * (1.0 - damage_reduction))

	stats_manager.get_stat("health").current_value -= final_damage # Changed from base_value
	stats_manager.get_stat("health").current_value = max(0, stats_manager.get_stat("health").current_value) # Changed from base_value and computed_value

	update_hp_label()
	emit_signal("damage_taken", final_damage, global_position) # Emit signal
	#print(name, "가 ", final_damage, " 데미지를 받았습니다. 남은 HP: ", stats_manager.get_stat("health").computed_value)
	if stats_manager.get_stat("health").current_value <= 0: # Changed from computed_value
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

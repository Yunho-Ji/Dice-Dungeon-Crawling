class_name Character
extends CharacterBody2D

signal damage_taken(amount: int, position: Vector2)

enum Stance { ATTACK, DEFENSE, EVADE }

# Battle variables
var action_gauge: float = 0.0
var target: CharacterBody2D
var ui_manager: Node
var is_in_battle: bool = false
var is_acting: bool = false # 현재 행동(공격 모션 등) 수행 중 여부
var is_selected: bool = false # 현재 선택된 타겟인지 여부
var is_player: bool = false # 플레이어 여부
var current_stance: Stance = Stance.ATTACK # 현재 스탠스
var active_status_effects: Array[StatusEffect] = [] # 활성 상태 효과 (버프, 디버프, DOT 등)
var character_data: CharacterData # 캐릭터의 기본 데이터를 담을 변수
var _stat_signals_connected: bool = false # 스탯 신호 연결 여부 플래그
var current_stats: MyCharacterStats # 실제 런타임 스탯 데이터 (MyStatsManager 대체)

# [신규] 방어구 유형별 장착 정보 (PlayerManager에서 동기화)
var cloth_pieces: int = 0
var light_pieces: int = 0
var heavy_pieces: int = 0

# [신규] 상태 이상 관련 변수
var is_vulnerable: bool = false
var vulnerable_timer: float = 0.0

func initialize(data: CharacterData):
	self.character_data = data
	is_player = (name == "Player")
	# 중요: 리소스 공유 문제를 피하기 위해 스탯 리소스를 복제합니다.
	print("DEBUG: Character.gd: Initializing with CharacterData: ", data.character_name)
	
	if data and data.base_stats:
		current_stats = data.base_stats.duplicate(true)
		print("DEBUG: Character.gd: Stats initialized from CharacterData.")
	else:
		printerr("ERROR: Character.gd: Invalid CharacterData or base_stats provided for initialization.")

	# 초기화 후 스탯 라벨 업데이트 등 필요한 작업 수행
	update_hp_label()

# [신규] 방어구 정보 동기화
func sync_armor_profile(counts: Dictionary):
	cloth_pieces = counts.get("cloth", 0)
	light_pieces = counts.get("light", 0)
	heavy_pieces = counts.get("heavy", 0)
	
	# 중갑 패널티 및 경갑 보너스 실시간 적용 (모션 속도)
	_update_motion_speed_modifiers()

func _update_motion_speed_modifiers():
	if not current_stats: return
	var stat = current_stats.get_stat("motion_speed")
	if not stat: return
	
	stat.clear_modifiers()
	
	# 중갑 패널티 (곱연산)
	if heavy_pieces > 0:
		var penalty = 1.0 - (heavy_pieces * 0.05 + 0.1) # 1피스 -15%, 4피스 -30% (가이드 기반 조정)
		var mod = MyStatModifier.new()
		mod.value = penalty
		mod.operation = MyStatModifier.Operation.MULTIPLY
		mod.target_stat_key = "HeavyArmorPenalty"
		stat.add_modifier(mod)
		
	# 경갑 보너스 (곱연산)
	if light_pieces > 0:
		var bonus = 1.0 + (light_pieces * 0.04 + 0.01) # 1피스 +5%, 4피스 +17% (가이드 기반 조정)
		var mod = MyStatModifier.new()
		mod.value = bonus
		mod.operation = MyStatModifier.Operation.MULTIPLY
		mod.target_stat_key = "LightArmorBonus"
		stat.add_modifier(mod)

func set_selected(selected: bool):
	is_selected = selected
	# 시각적 피드백: 선택 시 밝게 표시
	if is_selected:
		modulate = Color(1.5, 1.5, 1.5)
	else:
		modulate = Color(1, 1, 1)

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

@onready var action_gauge_bar = $ProgressBar
@onready var hp_label = $Label

func _ready():
	print("DEBUG: Character.gd: _ready called for ", name) # New line
	set_process(true) # 재생 등을 위해 프로세스 항상 켬
	input_pickable = true
	action_gauge = 0.0
	connect("input_event", Callable(self, "_on_input_event"))
	action_gauge_bar.position = Vector2(-32, -45)
	hp_label.position = Vector2(-32, 20)

func _process(delta: float):
	if not current_stats: return
	
	# 취약 상태 타이머
	if is_vulnerable:
		vulnerable_timer -= delta
		if vulnerable_timer <= 0:
			is_vulnerable = false
			modulate = Color(1, 1, 1)

	# 마나 재생 (지능 및 회복력 기반, 정수형 처리)
	var int_val = current_stats.get_stat("intelligence").computed_value
	var rec_val = current_stats.get_stat("recovery_power").computed_value
	var mp_regen_amount = (int_val * 0.2 + rec_val * 0.1) * delta 
	
	var mp_stat = current_stats.get_stat("current_mp")
	if mp_stat.current_value < mp_stat.computed_value:
		# 소수점 누적으로 인한 손실을 방지하기 위해 float 상태로 더한 뒤 저장 시 정수화
		var new_mp = float(mp_stat.current_value) + mp_regen_amount
		mp_stat.current_value = int(min(float(mp_stat.computed_value), new_mp))

	if current_stats.get_stat("health").current_value <= 0:
		action_gauge_bar.value = 0
		action_gauge = 0.0
		return
	
	if is_in_battle:
		# 상태 효과 지속 시간 업데이트
		var effects_to_remove = []
		for effect in active_status_effects:
			if not effect.update_duration(delta):
				effects_to_remove.append(effect)
		for effect in effects_to_remove:
			remove_status_effect(effect)

		# 행동 게이지 충전
		if target != null and is_instance_valid(target) and target.current_stats.get_stat("health").current_value > 0:
			if current_stance != Stance.DEFENSE and not is_acting:
				var charge_speed = current_stats.get_stat("attack_speed").computed_value
				
				# [신규] 마을 패널티(피로) 반영
				if GameManager.active_penalties.has("fatigue"):
					charge_speed *= 0.85 # 속도 15% 감소
					
				action_gauge += charge_speed * delta
			
			action_gauge_bar.value = action_gauge

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
		is_acting = true # 행동 시작
		action_gauge = 0.0 # 게이지 즉시 비움 (충전은 아직 안됨)
		action_gauge_bar.value = action_gauge
		attack(target)
	else:
		print(name, " 공격할 대상이 없습니다.")
		# 타겟이 없어도 게이지를 소모하고 행동을 마친 것으로 처리
		action_gauge = 0.0
		action_gauge_bar.value = action_gauge
		finish_action()

var is_guarding: bool = false
var is_perfect_guarding: bool = false

func perform_defense_action():
	# 선불제 방어: 즉시 비용 지불하고 태세 돌입
	# 방어는 '상태'이므로 is_acting을 쓰지 않고 _process의 stance 체크로 게이지를 유지함
	var upfront_cost = 15.0
	action_gauge = max(0.0, action_gauge - upfront_cost)
	is_guarding = true
	is_perfect_guarding = false 
	
	print(name, " 방어 태세 돌입! (선불 비용: ", upfront_cost, ", 잔여 게이지: ", action_gauge, "%)")
	action_gauge_bar.value = action_gauge # UI 즉시 갱신

const STATPOWDEBUFF_Data = preload("res://resources/status_effects/data/STATPOWDEBUFF_Data.tres")

func perform_evade_action():
	is_acting = true # 행동 시작
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
	finish_action() # 회피는 현재 별도 애니메이션이 없으므로 즉시 종료

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# 마우스 왼쪽 클릭: 타겟팅 처리 (플레이어가 아닌 적 캐릭터를 클릭했을 때)
			if not is_player and is_in_battle:
				var battle_manager = GameManager.battle_manager
				if battle_manager and battle_manager.has_method("set_player_target"):
					battle_manager.set_player_target(self)
					print("Targeting: ", name)

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 마우스 오른쪽 클릭: 정보 팝업 표시 (적/아군 공통)
			if GameManager.ui_manager and GameManager.ui_manager.has_method("show_character_info"):
				GameManager.ui_manager.show_character_info(self)
	

func take_damage(amount: int, piercing_rate: float = 0.0, true_damage_rate: float = 0.0):
	if not current_stats: return

	# 0. 회피 및 빗겨맞음 (경갑/민첩 시너지)
	var base_evasion = light_pieces * 5.0 
	if randf() * 100.0 < base_evasion:
		print(name, " >>> 완전 회피! (Damage: 0) <<<")
		emit_signal("damage_taken", 0, global_position)
		return

	var final_raw_damage = float(amount)
	
	# 빗겨맞음 판정 (민첩 기반)
	var agility_val = current_stats.get_stat("agility").computed_value
	var glance_chance = agility_val * 0.5 
	if randf() * 100.0 < glance_chance:
		final_raw_damage *= 0.5
		print(name, " >>> 빗겨맞음! (Damage 50% 감소) <<<")

	# 1. 트루 데미지 분리 (정수화)
	var true_damage_amount = int(final_raw_damage * true_damage_rate)
	var normal_damage_amount = int(final_raw_damage) - true_damage_amount
	
	var damage_reduction_pct = 0.0
	var retained_gauge_val = -1.0 
	
	# 2. 방어 판정 (일반 데미지에만 적용)
	if is_guarding:
		var defense_points = current_stats.get_stat("defense").computed_value
		var pg_threshold = max(40.0, 85.0 - (defense_points * 0.5))
		
		if action_gauge >= pg_threshold:
			print(name, " >>> 퍼펙트 가드 성공! <<<")
			damage_reduction_pct = 0.9
			retained_gauge_val = 50.0
			is_perfect_guarding = true 
		elif action_gauge >= 30.0:
			damage_reduction_pct = 0.3
			retained_gauge_val = 15.0
		
		is_guarding = false
		current_stance = Stance.ATTACK 
		if retained_gauge_val >= 0:
			action_gauge = retained_gauge_val
		action_gauge_bar.value = action_gauge

	# 3. 중갑 DR% 적용
	var heavy_dr_bonus = heavy_pieces * 0.05 
	damage_reduction_pct = min(0.9, damage_reduction_pct + heavy_dr_bonus)

	# 4. 방어력 및 관통 계산 (정수화)
	var target_defense = current_stats.get_stat("defense").computed_value
	var effective_defense = int(target_defense * (1.0 - piercing_rate))
	var processed_normal_damage = max(0, normal_damage_amount - effective_defense)
	processed_normal_damage = int(processed_normal_damage * (1.0 - damage_reduction_pct))

	# 5. 마나 실드 (천 방어구 기믹)
	if cloth_pieces > 0 and not is_vulnerable:
		var absorb_rate = cloth_pieces * 0.15 
		var damage_to_absorb = int(processed_normal_damage * absorb_rate)
		var mp_cost = int(ceil(damage_to_absorb / 2.0)) # 1:2 비율, 올림 처리로 마나 소모 보수적 적용
		
		var mp_stat = current_stats.get_stat("current_mp")
		if mp_stat.current_value >= mp_cost:
			mp_stat.current_value -= mp_cost
			processed_normal_damage -= damage_to_absorb
			print(name, " 마나 실드: ", damage_to_absorb, " 흡수 (MP -", mp_cost, ")")
		else:
			# 마나 부족 시 실드 브레이크
			var partial_absorb = mp_stat.current_value * 2
			processed_normal_damage -= partial_absorb
			mp_stat.current_value = 0
			_trigger_shield_break()
			print(name, " >>> 마나 실드 브레이크! <<<")

	# 6. 취약 상태 (치명타 1.5배, 정수화)
	if is_vulnerable:
		processed_normal_damage = int(processed_normal_damage * 1.5)
		print(name, " >>> 취약함: 데미지 증폭! <<<")

	# 7. 최종 체력 타격
	var final_hp_damage = true_damage_amount + processed_normal_damage
	
	# 보호막 처리
	var shield_stat = current_stats.get_stat("shield")
	if shield_stat and shield_stat.current_value > 0:
		var absorption = min(shield_stat.current_value, final_hp_damage)
		shield_stat.current_value -= int(absorption)
		final_hp_damage -= int(absorption)

	current_stats.get_stat("health").current_value = max(0, current_stats.get_stat("health").current_value - int(final_hp_damage))

	# 8. AP Knockback (피격 경직, 정수형 감소량)
	if not is_perfect_guarding:
		var res_multiplier = 1.0 + (heavy_pieces * 0.125) 
		var res_val = current_stats.get_stat("resistance").computed_value * res_multiplier
		
		# 최종 AP 감소량을 정수로 계산 (최소 1 보장 또는 0)
		var ap_loss_float = (final_hp_damage * 0.5) * (100.0 / (100.0 + res_val))
		var ap_loss_int = int(round(ap_loss_float))
		
		action_gauge = max(0.0, action_gauge - ap_loss_int)
		action_gauge_bar.value = action_gauge
		if ap_loss_int > 0:
			print(name, " 경직: AP ", ap_loss_int, " 감소 (저항 효율: ", res_multiplier, "x)")

	update_hp_label()
	emit_signal("damage_taken", int(final_hp_damage), global_position)
	is_perfect_guarding = false 

	if current_stats.get_stat("health").current_value <= 0:
		print(name, " 사망!")
		visible = false 
		set_process(false)

func _trigger_shield_break():
	is_vulnerable = true
	vulnerable_timer = 5.0 # 5초간 취약
	action_gauge = 0.0
	action_gauge_bar.value = 0.0
	# 시각적 피드백 (보라색 등)
	modulate = Color(0.7, 0.5, 1.0)


func update_hp_label():
	if not current_stats: return
	print("DEBUG: update_hp_label called by signal system!")
	hp_label.text = "HP: " + str(current_stats.get_stat("health").current_value) + "/" + str(current_stats.get_stat("health").computed_value)

func attack(target_node: CharacterBody2D):
	if not current_stats: return
	
	# [신규] 모션 속도(Motion Speed) 적용
	var motion_speed_stat = current_stats.get_stat("motion_speed")
	if motion_speed_stat and has_node("AnimatedSprite2D"):
		var sprite = get_node("AnimatedSprite2D")
		sprite.speed_scale = motion_speed_stat.computed_value
		# print(name, " 모션 속도 적용: ", sprite.speed_scale)

	var piercing_rate = current_stats.get_stat("piercing").computed_value
	var true_damage_rate = current_stats.get_stat("true_damage").computed_value
	target_node.take_damage(current_stats.get_stat("attack_power").computed_value, piercing_rate, true_damage_rate)
	
	# 플레이어가 아닌 경우(애니메이션 미연동 상태) 즉시 종료 처리
	if not is_player:
		finish_action()

func finish_action():
	is_acting = false
	# print(name, " 행동 완료. 게이지 획득 재개.")

## 전투 시작/준비 시 상태를 깨끗하게 초기화
func reset_battle_state():
	action_gauge = 0.0
	if action_gauge_bar: action_gauge_bar.value = 0.0
	is_acting = false
	is_guarding = false
	is_perfect_guarding = false
	current_stance = Stance.ATTACK
	# print(name, " 전투 상태 초기화 완료.")


func update_stats_from_player_manager(player_mgr: PlayerManager):
	if player_mgr and player_mgr.current_player_stats:
		# Synchronize the character's local stats with the PlayerManager's session stats.
		current_stats.sync_from(player_mgr.current_player_stats)

		print("DEBUG: Character.gd: Stats updated from PlayerManager.current_player_stats for ", name)
		
		# Connect stat signals for real-time UI updates, only once.
		if not _stat_signals_connected:
			for stat in current_stats.get_all_stats():
				if stat and not stat.value_changed.is_connected(update_hp_label):
					stat.value_changed.connect(update_hp_label)
			_stat_signals_connected = true
			print("DEBUG: Character.gd: Stat signals connected for real-time updates.")

		update_hp_label() # Refresh HP display
	else:
		printerr("ERROR: Character.gd: PlayerManager or current_player_stats not valid for updating stats.")

func set_level(p_stage: int, p_battle_count: int, hp_multiplier: float):
	if not current_stats: return
	print("DEBUG: set_level function called for '", name, "'")
	
	# 초기화: 기존 Modifier 제거
	for stat_key in current_stats.get_all_stat_keys():
		var stat = current_stats.get_stat(stat_key)
		if stat:
			StatManager.clear_modifiers(stat) # StatManager 사용

	# Health scaling
	var health_stat = current_stats.get_stat("health")
	if health_stat:
		var hp_bonus = int(health_stat.base_value * (hp_multiplier - 1.0))
		StatManager.add_modifier(health_stat, hp_bonus, MyStatModifier.Operation.ADD, "LevelScaling")
		
		# After scaling, reset current HP to the new max HP
		health_stat.current_value = health_stat.computed_value

	# Attack scaling
	var attack_stat = current_stats.get_stat("attack_power")
	if attack_stat:
		# p_stage 값은 임시 로직입니다.
		StatManager.add_modifier(attack_stat, p_stage, MyStatModifier.Operation.ADD, "LevelScaling")
		attack_stat.current_value = attack_stat.computed_value

	# Defense scaling
	var defense_stat = current_stats.get_stat("defense")
	if defense_stat:
		StatManager.add_modifier(defense_stat, p_battle_count, MyStatModifier.Operation.ADD, "LevelScaling")
	
	update_hp_label()

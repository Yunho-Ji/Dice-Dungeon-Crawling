class_name StatInterpreter

# PlayerManager에 있던 스탯 파싱 로직을 분리하여 SRP 준수.
# 레거시 데이터(JSON)와 새로운 Effect 시스템 간의 다리(Bridge) 역할.

## JSON 통계 데이터를 ItemEffect 배열로 변환
static func parse_stats(stats_data: Dictionary) -> Array[ItemEffect]:
	var effects: Array[ItemEffect] = []
	
	for stat_key in stats_data.keys():
		var raw_value = stats_data[stat_key]
		var value = 0.0
		
		# [값 전처리]
		if raw_value is Array:
			if raw_value.size() >= 2:
				value = (raw_value[0] + raw_value[1]) / 2.0 # 평균값 사용
			elif raw_value.size() > 0:
				value = raw_value[0]
		elif raw_value is float or raw_value is int:
			value = float(raw_value)
		elif raw_value is String:
			# 상태 이상 ID 등 문자열 값은 아래에서 별도 처리
			pass
		
		# -------------------------------------------------------
		# [1. Action Trigger Effects (특수 효과)]
		# -------------------------------------------------------
		if stat_key == "vampiric_pct":
			var trigger_effect = ActionTriggerEffect.new()
			trigger_effect.trigger = ActionTriggerEffect.TriggerType.ON_HIT
			trigger_effect.action = ActionTriggerEffect.ActionType.HEAL_SELF
			trigger_effect.value = value / 100.0 if value > 1.0 else value # 10% -> 0.1, 0.1 -> 0.1
			trigger_effect.chance = 1.0
			effects.append(trigger_effect)
			continue
			
		if stat_key == "extra_damage_pct":
			var trigger_effect = ActionTriggerEffect.new()
			trigger_effect.trigger = ActionTriggerEffect.TriggerType.ON_HIT
			trigger_effect.action = ActionTriggerEffect.ActionType.EXTRA_DAMAGE
			trigger_effect.value = value / 100.0 if value > 1.0 else value
			trigger_effect.chance = 1.0
			effects.append(trigger_effect)
			continue
			
		if stat_key == "on_hit_status":
			var trigger_effect = ActionTriggerEffect.new()
			trigger_effect.trigger = ActionTriggerEffect.TriggerType.ON_HIT
			trigger_effect.action = ActionTriggerEffect.ActionType.APPLY_STATUS
			
			# 리소스 로드 시도 (명명 규칙: DoT{NAME}_Data.tres)
			var status_id = str(raw_value).to_upper()
			var path = "res://resources/status_effects/data/DoT%s_Data.tres" % status_id
			
			# 접두어 없이 시도 (예: STUN_Data.tres)
			if not FileAccess.file_exists(path):
				path = "res://resources/status_effects/data/%s_Data.tres" % status_id
				
			if FileAccess.file_exists(path):
				trigger_effect.status_effect = load(path)
				trigger_effect.chance = 0.3 # TODO: JSON에 확률 필드가 없으므로 기본값 설정
				effects.append(trigger_effect)
			else:
				printerr("StatInterpreter: Status effect resource not found for '%s'" % raw_value)
			continue

		# -------------------------------------------------------
		# [2. Stat Modifiers (스탯 보정)]
		# -------------------------------------------------------
		var target_key = StatManager.normalize_stat_key(stat_key)
		var modifier_value = 0.0
		var is_multiplier = false
		
		# [2차 스탯 마이그레이션 & 레거시 호환]
		match stat_key:
			"min_atk", "max_atk":
				target_key = "atk"
				modifier_value = int(value * 0.5) # 평균 데미지로 변환
			"dr_rate":
				# 방어율 -> 방어력(Defense)으로 변환 (임시 공식)
				target_key = "defense"
				modifier_value = int(value) 
			"evade_rate":
				# 회피율 -> 민첩(AGI)으로 변환 (임시 공식)
				target_key = "agi"
				modifier_value = int(value)
			"hp_max", "max_hp":
				target_key = "health" # StatManager 표준 키 사용
				modifier_value = int(value)
			"mp_max", "max_mp":
				target_key = "current_mp" # StatManager 표준 키 사용 (보통 max_mp 스탯이 따로 없으면 current_mp의 computed_value를 늘림)
				modifier_value = int(value)
			"str":
				target_key = "atk" # DDC 프로토타입 특성상 STR이 ATK로 직결되는 경우가 많음 (확인 필요)
				modifier_value = int(value)
			_:
				# 별도 매핑 없는 경우 원본 값 사용
				modifier_value = value

		if target_key != "":
			var effect = StatModifierEffect.new()
			effect.stat_key = target_key
			effect.value = modifier_value
			effect.is_multiplier = is_multiplier
			effects.append(effect)
			
	return effects

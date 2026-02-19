class_name StatInterpreter

# PlayerManager에 있던 스탯 파싱 로직을 분리하여 SRP 준수.
# 레거시 데이터(JSON)와 새로운 Effect 시스템 간의 다리(Bridge) 역할.

## JSON 통계 데이터를 StatModifierEffect 배열로 변환
static func parse_stats(stats_data: Dictionary) -> Array[StatModifierEffect]:
	var effects: Array[StatModifierEffect] = []
	
	for stat_key in stats_data.keys():
		var raw_value = stats_data[stat_key]
		var value = 0.0
		
		# [배열 값 처리]
		if raw_value is Array:
			if raw_value.size() >= 2:
				value = (raw_value[0] + raw_value[1]) / 2.0 # 평균값
			elif raw_value.size() > 0:
				value = raw_value[0]
		elif raw_value is float or raw_value is int:
			value = float(raw_value)
		
		var target_key = StatManager.normalize_stat_key(stat_key)
		var modifier_value = 0
		var is_multiplier = false
		
		# [특수 키 매핑 로직] (PlayerManager에서 이동됨)
		if stat_key == "min_atk" or stat_key == "max_atk":
			target_key = "atk"
			modifier_value = int(value * 0.5) 
		elif stat_key == "dr_rate":
			target_key = "defense"
			modifier_value = int(value) 
		elif stat_key == "evade_rate":
			target_key = "agi"
			modifier_value = int(value) 
		elif stat_key == "hp_max":
			target_key = "vit" 
			modifier_value = int(value / 10.0) 
		elif stat_key == "str":
			target_key = "atk"
			modifier_value = int(value)
		else:
			# 일반적인 경우
			modifier_value = int(value)

		if target_key != "":
			var effect = StatModifierEffect.new()
			effect.stat_key = target_key
			effect.value = modifier_value
			effect.is_multiplier = is_multiplier
			effects.append(effect)
			
	return effects

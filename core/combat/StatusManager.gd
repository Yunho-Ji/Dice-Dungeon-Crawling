extends Node

# StatusManager (구 EffectManager)
# 역할: 모든 상태이상(Buff/Debuff)의 데이터 정의와 팩토리 역할을 수행합니다.
# 실제 틱(Tick) 처리는 각 개체의 StatusReceiver 컴포넌트가 담당합니다.

enum Type { POISON, BURN, STUN, BLEED }

func get_status_data(type: Type) -> Dictionary:
	# 예시 데이터 반환
	match type:
		Type.POISON:
			return {"name": "Poison", "duration": 3, "tick_damage": 5}
	return {}

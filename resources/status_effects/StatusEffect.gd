extends Resource
class_name StatusEffect

@export var data: StatusEffectData # 상태 효과 데이터 템플릿

var _time_remaining: float = 0.0
var _is_active: bool = false

func _init():
	if data:
		_time_remaining = data.duration

func apply_effect(character: Character):
	if _is_active or not data: return
	_is_active = true
	for modifier in data.modifiers:
		# MyStatModifier에 target_stat_key가 있으므로 직접 적용
		character.stats_manager.add_modifier(modifier.target_stat_key, modifier)

func remove_effect(character: Character):
	if not _is_active or not data: return
	_is_active = false
	for modifier in data.modifiers:
		character.stats_manager.remove_modifier(modifier.target_stat_key, modifier)

func update_duration(delta: float) -> bool:
	if not data or data.duration == 0.0: return true # 데이터가 없거나 무한 지속 시간
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		return false # 효과 만료
	return true # 효과 활성 중

func get_time_remaining() -> float:
	return _time_remaining

func is_active() -> bool:
	return _is_active

func get_effect_name() -> String:
	if data: return data.effect_name
	return ""

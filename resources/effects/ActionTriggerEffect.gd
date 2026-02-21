extends ItemEffect
class_name ActionTriggerEffect

enum TriggerType { 
	ON_ATTACK,       # 공격 행동 시작 시
	ON_HIT,          # 공격 성공 시 (타겟에게 데미지 전달 후)
	ON_DAMAGE_TAKEN, # 피격 시
	ON_TURN_START    # (미구현) 턴 시작 시
}

enum ActionType {
	EXTRA_DAMAGE,    # 추가 데미지 부여
	HEAL_SELF,       # 자가 치유
	APPLY_STATUS,    # 상태 이상 부여 (타겟 혹은 자신)
	GAIN_AP          # 행동 게이지 획득
}

@export var trigger: TriggerType = TriggerType.ON_HIT
@export var action: ActionType = ActionType.EXTRA_DAMAGE
@export var chance: float = 1.0 # 0.0 ~ 1.0 (발동 확률)
@export var value: float = 0.0 # 데미지 비율, 치유량 등
@export var status_effect: StatusEffectData # APPLY_STATUS 일 때 사용
@export var target_self: bool = false # 효과 대상을 자신으로 할지 여부

var _owner: Character = null

func apply(target: Character):
	_owner = target
	_connect_signals()
	print("DEBUG: ActionTriggerEffect applied to ", target.name, " (Trigger: ", TriggerType.keys()[trigger], ")")

func remove(target: Character):
	_disconnect_signals()
	_owner = null
	print("DEBUG: ActionTriggerEffect removed from ", target.name)

func _connect_signals():
	if not _owner: return
	
	match trigger:
		TriggerType.ON_ATTACK:
			if not _owner.action_started.is_connected(_on_action_started):
				_owner.action_started.connect(_on_action_started)
		TriggerType.ON_HIT:
			if not _owner.hit_target.is_connected(_on_hit_target):
				_owner.hit_target.connect(_on_hit_target)
		TriggerType.ON_DAMAGE_TAKEN:
			if not _owner.damage_taken.is_connected(_on_damage_taken):
				_owner.damage_taken.connect(_on_damage_taken)

func _disconnect_signals():
	if not _owner: return
	
	if _owner.action_started.is_connected(_on_action_started):
		_owner.action_started.disconnect(_on_action_started)
	if _owner.hit_target.is_connected(_on_hit_target):
		_owner.hit_target.disconnect(_on_hit_target)
	if _owner.damage_taken.is_connected(_on_damage_taken):
		_owner.damage_taken.disconnect(_on_damage_taken)

func _on_action_started(stance: Character.Stance):
	if stance == Character.Stance.ATTACK:
		_execute_trigger(null, 0)

func _on_hit_target(target: Character, damage: int):
	_execute_trigger(target, damage)

func _on_damage_taken(amount: int, _pos: Vector2):
	# 피격 시에는 보통 공격자를 알 수 없지만(현재 시그널 구조상), 
	# 필요한 경우 _owner를 대상으로 효과를 적용합니다.
	_execute_trigger(null, amount)

func _execute_trigger(target: Character, base_value: float):
	if randf() > chance: return
	
	var effect_target = _owner if target_self or target == null else target
	
	match action:
		ActionType.EXTRA_DAMAGE:
			if target and is_instance_valid(target):
				var extra = int(base_value * value)
				if extra > 0:
					target.take_damage(extra, 1.0, 0.0) # 추가 데미지는 보통 방무(Piercing 100%)
					print("DEBUG: Extra Damage Triggered: ", extra)
		
		ActionType.HEAL_SELF:
			var heal_amount = int(base_value * value) if trigger == TriggerType.ON_HIT else int(value)
			var hp = _owner.current_stats.get_stat("health")
			if hp:
				hp.current_value = min(hp.computed_value, hp.current_value + heal_amount)
				_owner.update_hp_label()
				print("DEBUG: Heal Triggered: ", heal_amount)
				
		ActionType.APPLY_STATUS:
			if status_effect and effect_target:
				effect_target.add_status_effect(status_effect)
				print("DEBUG: Status Effect Triggered: ", status_effect.effect_name)
				
		ActionType.GAIN_AP:
			var ap_gain = value
			_owner.action_gauge = min(100.0, _owner.action_gauge + ap_gain)
			print("DEBUG: AP Gain Triggered: ", ap_gain)

func get_description() -> String:
	var trigger_str = ""
	match trigger:
		TriggerType.ON_ATTACK: trigger_str = "공격 시"
		TriggerType.ON_HIT: trigger_str = "적중 시"
		TriggerType.ON_DAMAGE_TAKEN: trigger_str = "피격 시"
	
	var action_str = ""
	match action:
		ActionType.EXTRA_DAMAGE: action_str = "%d%% 추가 피해" % int(value * 100)
		ActionType.HEAL_SELF: action_str = "생명력 %d 회복" % int(value)
		ActionType.APPLY_STATUS: action_str = "[%s] 부여" % (status_effect.effect_name if status_effect else "상태이상")
		ActionType.GAIN_AP: action_str = "기력 %.1f 획득" % value
		
	return "%s %d%% 확률로 %s" % [trigger_str, int(chance * 100), action_str]

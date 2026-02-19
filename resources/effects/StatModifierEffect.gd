extends ItemEffect
class_name StatModifierEffect

@export var stat_key: String = ""
@export var value: float = 0.0
@export var is_multiplier: bool = false # True if this is a percentage bonus (e.g., +10%)

# Internal reference to the applied modifier object (to remove it later)
var _applied_modifier: MyStatModifier

func apply(target: Character):
	if not target or not target.current_stats: return
	
	var stat = target.current_stats.get_stat(stat_key)
	if not stat:
		# Try looking up via StatManager normalizer if needed, but resource should have correct key.
		stat = target.current_stats.get_stat(StatManager.normalize_stat_key(stat_key))
	
	if stat:
		_applied_modifier = MyStatModifier.new()
		_applied_modifier.value = value
		_applied_modifier.target_stat_key = stat.key
		
		if is_multiplier:
			_applied_modifier.operation = MyStatModifier.Operation.MULTIPLY
		else:
			_applied_modifier.operation = MyStatModifier.Operation.ADD
			
		stat.add_modifier(_applied_modifier)
		print("DEBUG: StatModifierEffect applied: ", stat.key, " ", value)

func remove(target: Character):
	if not target or not target.current_stats: return
	if not _applied_modifier: return
	
	var stat = target.current_stats.get_stat(_applied_modifier.target_stat_key)
	if stat:
		stat.remove_modifier(_applied_modifier)
		print("DEBUG: StatModifierEffect removed: ", stat.key)
	
	_applied_modifier = null

func get_description() -> String:
	var op_str = "+" if not is_multiplier else "x"
	var val_str = str(value)
	if is_multiplier: val_str = str(value * 100) + "%"
	return "%s %s%s" % [stat_key.to_upper(), op_str, val_str]

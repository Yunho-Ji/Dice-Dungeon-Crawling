extends Resource
class_name MyStat

signal value_changed(new_value)

@export var key: String = "" # Unique identifier for the stat
@export var base_value: int = 0
@export var current_value: int = 0
var modifiers: Array = [] # Array of MyStatModifier resources

var computed_value: int:
	get:
		# 로직 분리: 계산 로직을 StatManager로 위임
		if StatManager:
			return StatManager.calculate_stat_value(self)
		return base_value

func add_modifier(modifier: MyStatModifier):
	if not modifiers.has(modifier):
		modifiers.append(modifier)
		_emit_value_changed()

func remove_modifier(modifier: MyStatModifier):
	if not modifiers.has(modifier):
		modifiers.erase(modifier)
		_emit_value_changed()

func clear_modifiers():
	if not modifiers.is_empty():
		modifiers.clear()
		_emit_value_changed()

func _emit_value_changed():
	# 디버그 로그 제거 또는 간소화
	# print("DEBUG: MyStat: value_changed", key, computed_value)
	value_changed.emit() # Emit without argument for now, or match signal signature

# Synchronizes this stat's values from a source stat object.
func sync_from(source_stat):
	if not source_stat:
		printerr("ERROR: MyStat: source_stat for sync_from is null.")
		return

	self.base_value = source_stat.base_value
	self.current_value = source_stat.current_value
	
	# Deep copy the modifiers array
	self.modifiers.clear()
	for modifier in source_stat.modifiers:
		var new_modifier = MyStatModifier.new()
		new_modifier.value = modifier.value
		new_modifier.operation = modifier.operation
		new_modifier.target_stat_key = modifier.target_stat_key
		self.modifiers.append(new_modifier)
	
	_emit_value_changed()
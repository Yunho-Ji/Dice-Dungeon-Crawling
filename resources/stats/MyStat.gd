extends Resource
class_name MyStat

signal value_changed(new_value)

@export var key: String = "" # Unique identifier for the stat
@export var base_value: int = 0
@export var current_value: int = 0
var modifiers: Array = [] # Array of MyStatModifier resources

var computed_value: int:
	get:
		return _calculate_computed_value()

func _calculate_computed_value() -> int:
	var effective_value = base_value # Start with base_value
	for modifier in modifiers:
		if modifier is MyStatModifier:
			effective_value = modifier.apply(effective_value) # Corrected line
	return effective_value

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
	print("DEBUG: MyStat: value_changed signal emitted from instance: ", get_instance_id(), " for key: ", key, ", new computed_value: ", computed_value)
	value_changed.emit() # Emit without argument

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
	
	# After copying, emit a signal so any connected UI updates.
	_emit_value_changed()

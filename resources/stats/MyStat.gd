extends Resource
class_name MyStat

signal value_changed(new_value)

var key: String = "" # Unique identifier for the stat
var base_value: Variant = 0
var modifiers: Array = [] # Array of MyStatModifier resources

var computed_value: Variant:
	get:
		return _calculate_computed_value()

func _calculate_computed_value() -> Variant:
	var current_value = base_value
	for modifier in modifiers:
		if modifier is MyStatModifier:
			current_value = modifier.apply(current_value)
	return current_value

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
	value_changed.emit(computed_value)
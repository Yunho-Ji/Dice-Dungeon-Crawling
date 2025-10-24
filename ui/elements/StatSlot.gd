class_name StatSlot
extends Panel

@onready var stat_name_label: Label = $MarginContainer/VBoxContainer/StatNameLabel
@onready var assigned_value_label: Label = $MarginContainer/VBoxContainer/AssignedValueLabel
@onready var current_value_label: Label = $MarginContainer/VBoxContainer/CurrentValueLabel

@export var stat_name: String = ""
var current_stat_value: MyStat
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Allow dropping if it's a dice and no modifier from a dice is currently applied
	# We need to check if there's already a MyIntStatModifier from a dice
	if not (data is Dictionary and data.has("type") and data.type == "dice"):
		return false
	
	if current_stat_value:
		for modifier in current_stat_value.modifiers:
			if modifier is MyIntStatModifier and modifier.target_stat_key == stat_name: # Assuming target_stat_key is set for dice modifiers
				return false # A dice modifier is already applied to this slot
	return true

func _drop_data(_at_position: Vector2, data: Variant):
	print("DEBUG: StatSlot: _drop_data called!")
	if current_stat_value:
		var dice_modifier = MyIntStatModifier.new()
		dice_modifier.value = data.value
		dice_modifier.operation = MyStatModifier.Operation.ADD
		dice_modifier.target_stat_key = stat_name # Mark this modifier as coming from a dice for this stat
		current_stat_value.add_modifier(dice_modifier)
		
		# The update_display() will be triggered by the value_changed signal from MyStat
		
		if data.has("source_label") and is_instance_valid(data.source_label):
			data.source_label.queue_free()

func set_stat(p_stat_name: String, p_stat_value: MyStat): # Now accepts MyStat object
	stat_name = p_stat_name
	# Disconnect from previous stat's signal if it exists
	if current_stat_value and current_stat_value.value_changed.is_connected(update_display):
		current_stat_value.value_changed.disconnect(update_display)
	
	current_stat_value = p_stat_value
	
	# Connect to the new stat's signal
	print("DEBUG: StatSlot: Attempting to connect to MyStat instance: ", current_stat_value.get_instance_id(), " for stat: ", stat_name)
	if current_stat_value and not current_stat_value.value_changed.is_connected(update_display):
		var error = current_stat_value.value_changed.connect(update_display)
		if error != OK:
			printerr("ERROR: StatSlot: Failed to connect signal for stat: ", stat_name, " Error: ", error)
	
	print("DEBUG: StatSlot: Connected update_display for stat: ", stat_name)
	update_display()

func update_display():
	print("DEBUG: StatSlot: update_display called for stat: ", stat_name, ", computed_value: ", str(current_stat_value.computed_value) if current_stat_value else "N/A")
	stat_name_label.text = stat_name
	if current_stat_value:
		current_value_label.text = "(%s)" % str(current_stat_value.computed_value)
	else:
		current_value_label.text = "(N/A)"
	
	# Check if there's an active dice modifier to display
	var has_dice_modifier = false
	var dice_modifier_value = 0
	if current_stat_value:
		for modifier in current_stat_value.modifiers:
			if modifier is MyIntStatModifier and modifier.target_stat_key == stat_name:
				has_dice_modifier = true
				dice_modifier_value = modifier.value
				break
	
	if has_dice_modifier:
		assigned_value_label.text = "+%s" % str(dice_modifier_value)
		modulate = Color(0.7, 1.0, 0.7) # 할당되면 초록빛
	else:
		assigned_value_label.text = "-"
		modulate = Color(1, 1, 1)

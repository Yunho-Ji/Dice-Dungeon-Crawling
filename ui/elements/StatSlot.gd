class_name StatSlot
extends Panel

@onready var stat_name_label: Label = $MarginContainer/VBoxContainer/StatNameLabel
@onready var assigned_value_label: Label = $MarginContainer/VBoxContainer/AssignedValueLabel
@onready var current_value_label: Label = $MarginContainer/VBoxContainer/CurrentValueLabel

@export var stat_name: String = ""
var current_stat_value: MyStat
var assigned_dice_value: int = 0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data.type == "dice" and assigned_dice_value == 0

func _drop_data(_at_position: Vector2, data: Variant):
	assigned_dice_value = data.value
	update_display()

	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.player_node:
		var player_stat = game_manager.player_node.stats_manager.get_stat(stat_name)
		if player_stat:
			player_stat.base_value += assigned_dice_value
			print("스탯 즉시 적용: ", stat_name, "에 ", assigned_dice_value, ". 현재 값: ", player_stat.computed_value)
			game_manager.player_node.update_hp_label() # Assuming HP label needs update
		else:
			printerr("StatSlot: Unknown stat: ", stat_name)
	
	if data.has("source_label") and is_instance_valid(data.source_label):
		data.source_label.queue_free()

func set_stat(p_stat_name: String, p_stat_value: MyStat): # Now accepts MyStat object
	stat_name = p_stat_name
	# Connect to value_changed signal to update display automatically
	if current_stat_value != null: # Disconnect previous signal if any
		current_stat_value.value_changed.disconnect(update_display)
	current_stat_value = p_stat_value
	current_stat_value.value_changed.connect(update_display)
	update_display()

func update_display():
	stat_name_label.text = stat_name
	if current_stat_value:
		current_value_label.text = "(%s)" % str(current_stat_value.computed_value)
	else:
		current_value_label.text = "(N/A)"
	
	if assigned_dice_value != 0:
		assigned_value_label.text = "+%s" % str(assigned_dice_value)
		modulate = Color(0.7, 1.0, 0.7) # 할당되면 초록빛
	else:
		assigned_value_label.text = "-"
		modulate = Color(1, 1, 1)

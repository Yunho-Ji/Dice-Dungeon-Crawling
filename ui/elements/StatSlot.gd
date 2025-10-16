class_name StatSlot
extends Panel

@onready var stat_name_label: Label = $MarginContainer/VBoxContainer/StatNameLabel
@onready var assigned_value_label: Label = $MarginContainer/VBoxContainer/AssignedValueLabel
@onready var current_value_label: Label = $MarginContainer/VBoxContainer/CurrentValueLabel

@export var stat_name: String = ""
var current_stat_value: int = 0
var assigned_dice_value: int = 0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data.type == "dice" and assigned_dice_value == 0

func _drop_data(_at_position: Vector2, data: Variant):
	assigned_dice_value = data.value
	update_display()

	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.player_node:
		game_manager.player_node.apply_dice_to_stat(stat_name, assigned_dice_value)
		print("스탯 즉시 적용: ", stat_name, "에 ", assigned_dice_value)
	
	if data.has("source_label") and is_instance_valid(data.source_label):
		data.source_label.queue_free()

func set_stat(p_stat_name: String, p_current_value: int):
	stat_name = p_stat_name
	current_stat_value = p_current_value
	update_display()

func update_display():
	stat_name_label.text = stat_name
	current_value_label.text = "(%s)" % str(current_stat_value)
	
	if assigned_dice_value != 0:
		assigned_value_label.text = "+%s" % str(assigned_dice_value)
		modulate = Color(0.7, 1.0, 0.7) # 할당되면 초록빛
	else:
		assigned_value_label.text = "-"
		modulate = Color(1, 1, 1)

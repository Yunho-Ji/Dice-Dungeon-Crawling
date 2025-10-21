extends Control
signal closed

const DiceLabelScene = preload("res://ui/elements/DiceLabel.tscn")
const StatSlotScene = preload("res://ui/elements/StatSlot.tscn")

@onready var dice_manager = get_node("/root/DiceManager")
@onready var game_manager = get_node("/root/GameManager") # Still needed for player node access

@onready var stat_slots_container = $VBoxContainer/HBoxContainer/PanelA/StatSlotsContainer
@onready var dice_results_container = $VBoxContainer/HBoxContainer/PanelB/VBoxContainer/DiceResultsContainer
@onready var roll_dice_button = $VBoxContainer/HBoxContainer/PanelB/VBoxContainer/RollDiceButton
@onready var close_button = $VBoxContainer/PanelC/HBoxContainer/CloseButton

func _ready():
	print("DEBUG: DestinyDesignScreen.gd: _ready called.")
	close_button.pressed.connect(_on_close_button_pressed)
	roll_dice_button.pressed.connect(_on_roll_dice_button_pressed)
	dice_manager.dice_rolled.connect(_on_dice_rolled)
	
	_initialize_stat_slots()
	
	roll_dice_button.disabled = not dice_manager.can_roll()
	
	# Clear any old dice labels from a previous opening
	for child in dice_results_container.get_children():
		child.queue_free()

func _on_close_button_pressed():
	emit_signal("closed")

func _initialize_stat_slots():
	for child in stat_slots_container.get_children():
		child.queue_free()

	var stats_to_display = ["attack_power", "health", "defense", "attack_speed", "current_mp", "recovery_power", "luck", "resistance"]
	var player = game_manager.player_node
	if not player: return

	for stat_name in stats_to_display:
		var new_slot = StatSlotScene.instantiate()
		stat_slots_container.add_child(new_slot)
		
		var current_stat_value = player.stats_manager.get_stat(stat_name)
		
		if new_slot.has_method("set_stat"): 
			new_slot.set_stat(stat_name, current_stat_value)

func _on_roll_dice_button_pressed():
	print("DestinyDesignScreen: 주사위 굴리기 버튼 클릭")
	roll_dice_button.disabled = true # Visually disable immediately
	dice_manager.roll_player_dice() # Ask DiceManager to roll

func _on_dice_rolled(rolled_values: Array):
	# Clear old dice
	for child in dice_results_container.get_children():
		child.queue_free()

	# Display new dice
	for roll_value in rolled_values:
		var new_label = DiceLabelScene.instantiate()
		dice_results_container.add_child(new_label)
		new_label.text = str(roll_value)
		new_label.dice_value = roll_value
		new_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_initialize_stat_slots() # Refresh stat display after dice applied

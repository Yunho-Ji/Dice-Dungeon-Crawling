# DestinyDesignScreen.gd
extends Control
signal dice_roll_requested

const DiceLabelScene = preload("res://ui/elements/DiceLabel.tscn")
const StatSlotScene = preload("res://ui/elements/StatSlot.tscn")

@onready var dice_manager = get_node("/root/DiceManager")
@onready var game_manager = get_node("/root/GameManager")

# HBoxContainer/PanelA/PanelB 구조에 맞는 최종 경로
@onready var stat_slots_container = $VBoxContainer/HBoxContainer/PanelA/StatSlotsContainer
@onready var dice_results_container = $VBoxContainer/HBoxContainer/PanelB/VBoxContainer/DiceResultsContainer
@onready var roll_dice_button = $VBoxContainer/HBoxContainer/PanelB/VBoxContainer/RollDiceButton
@onready var close_button = $VBoxContainer/PanelC/HBoxContainer/CloseButton

# 레이아웃 문제를 해결하기 위한 노드 참조
@onready var panel_A = $VBoxContainer/HBoxContainer/PanelA

func _ready():
	print("DEBUG: DestinyDesignScreen.gd: _ready called.") # New line
	close_button.pressed.connect(queue_free)
	roll_dice_button.pressed.connect(_on_roll_dice_button_pressed)
	game_manager.dice_rolled_and_applied.connect(_on_dice_rolled_and_applied)
	
	_initialize_stat_slots()
	
	roll_dice_button.disabled = not game_manager.can_roll_new_dice
	
	for child in dice_results_container.get_children():
		child.queue_free()

func _initialize_stat_slots():
	for child in stat_slots_container.get_children():
		child.queue_free()

	var stats_to_display = ["attack_power", "max_hp", "defense", "attack_speed", "max_mp", "recovery_power", "luck", "resistance"]
	var player = game_manager.player_node
	if not player: return

	for stat_name in stats_to_display:
		var new_slot = StatSlotScene.instantiate()
		stat_slots_container.add_child(new_slot)
		
		var current_stat_value = player.get_stat(stat_name)
		
		if new_slot.has_method("set_stat"): 
			new_slot.set_stat(stat_name, current_stat_value)

func _on_roll_dice_button_pressed():
	print("DestinyDesignScreen: 주사위 굴리기 버튼 클릭")
	emit_signal("dice_roll_requested") # Emit signal instead of direct call
	roll_dice_button.disabled = true
	game_manager.can_roll_new_dice = false

func _on_dice_rolled_and_applied(rolled_values: Array):
	for child in dice_results_container.get_children():
		child.queue_free()

	for roll_value in rolled_values:
		var new_label = DiceLabelScene.instantiate()
		dice_results_container.add_child(new_label)
		new_label.text = str(roll_value)
		new_label.dice_value = roll_value
		new_label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	_initialize_stat_slots() # Refresh stat display after dice applied

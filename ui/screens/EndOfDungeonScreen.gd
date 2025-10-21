extends Control
signal return_to_town_requested
signal additional_exploration_requested

@onready var return_button = $VBoxContainer/ReturnButton
@onready var explore_button = $VBoxContainer/ExploreButton

func _ready():
	return_button.pressed.connect(_on_return_button_pressed)
	explore_button.pressed.connect(_on_explore_button_pressed)

func _on_return_button_pressed():
	emit_signal("return_to_town_requested")

func _on_explore_button_pressed():
	emit_signal("additional_exploration_requested")

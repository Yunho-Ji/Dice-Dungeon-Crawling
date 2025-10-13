extends Control

@onready var start_game_button = $StartGameButton

func _ready():
	start_game_button.pressed.connect(_on_start_game_button_pressed)

func _on_start_game_button_pressed():
	print("MainMenu: Start Game button pressed. Loading main game scene.")
	get_tree().change_scene_to_file("res://ui/CharacterSelect.tscn")

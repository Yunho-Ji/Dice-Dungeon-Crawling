extends Control

@onready var novice_button = $CharacterButtons/NoviceButton
@onready var archer_button = $CharacterButtons/ArcherButton
@onready var confirm_button = $ConfirmButton
@onready var developer_mode_button = $DeveloperModeButton # New line

var selected_character_type: String = ""

@onready var scene_manager: SceneManager = get_node("/root/SceneManager")
@onready var game_manager: GameManager = get_node("/root/GameManager")

func _ready():
	novice_button.pressed.connect(func(): _on_character_selected("novice"))
	archer_button.pressed.connect(func(): _on_character_selected("archer"))
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	developer_mode_button.pressed.connect(_on_developer_mode_button_pressed) # New line

func _on_character_selected(char_type: String):
	selected_character_type = char_type
	confirm_button.disabled = false
	print("Character selected: ", char_type)

func _on_confirm_button_pressed():
	if selected_character_type != "":
		print("Confirming selection: ", selected_character_type)
		scene_manager.start_game_with_character(selected_character_type)
	else:
		print("No character selected.")

func _on_developer_mode_button_pressed(): # New function
	game_manager.is_developer_mode = true
	print("개발자 모드 활성화됨.")
	confirm_button.disabled = false # Enable confirm button
	confirm_button.text = "선택 완료 (개발자 모드)" # Indicate developer mode
	novice_button.disabled = true
	archer_button.disabled = true

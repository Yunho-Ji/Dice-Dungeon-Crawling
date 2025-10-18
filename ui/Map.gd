extends Control

@onready var dungeon_buttons_container = $DungeonButtonsContainer
@onready var scene_manager: SceneManager = get_node("/root/SceneManager")

func _ready():
	print("DEBUG: Map.gd: _ready called.") # New line
	for i in range(1, 4): # Dungeon 1, 2, 3
		var button = Button.new()
		button.text = "던전 " + str(i)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_on_dungeon_button_pressed").bind(i))
		dungeon_buttons_container.add_child(button)

func _on_dungeon_button_pressed(dungeon_id: int):
	print("DEBUG: Map.gd: _on_dungeon_button_pressed called for Dungeon ", dungeon_id) # New line
	print("Selected Dungeon ", dungeon_id)
	scene_manager.start_dungeon(dungeon_id)

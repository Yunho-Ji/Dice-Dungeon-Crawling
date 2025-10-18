extends CanvasLayer

signal attack_stance_selected
signal defense_stance_selected
signal dodge_stance_selected
signal skill_1_used
signal skill_2_used
signal inventory_opened
signal destiny_design_opened
signal map_requested
signal start_combat_requested

@onready var destiny_design_button = $DestinyDesignButton
@onready var map_button = $MapButton
@onready var start_combat_button = $StartCombatButton
@export var damage_popup_scene: PackedScene

func _ready():
	print("DEBUG: BattleHUD.gd: _ready called.")
	$BattleControls/AttackButton.pressed.connect(_on_attack_button_pressed)
	$BattleControls/DefenseButton.pressed.connect(_on_defense_button_pressed)
	$BattleControls/DodgeButton.pressed.connect(_on_dodge_button_pressed)
	$BattleControls/Skill1Button.pressed.connect(_on_skill_1_button_pressed)
	$BattleControls/Skill2Button.pressed.connect(_on_skill_2_button_pressed)
	$InventoryButton.pressed.connect(_on_inventory_button_pressed)
	
	if destiny_design_button: destiny_design_button.pressed.connect(_on_destiny_design_button_pressed)
	if map_button: map_button.pressed.connect(_on_map_button_pressed)
	if start_combat_button: start_combat_button.pressed.connect(_on_start_combat_button_pressed)
	
	# Initially hide both buttons
	map_button.visible = false
	start_combat_button.visible = false

func set_destiny_button_enabled(is_enabled: bool):
	if destiny_design_button: destiny_design_button.disabled = not is_enabled

func show_map_button():
	if map_button: map_button.visible = true
	if start_combat_button: start_combat_button.visible = false

func show_start_combat_button():
	if map_button: map_button.visible = false
	if start_combat_button: start_combat_button.visible = true

func _on_attack_button_pressed():
	emit_signal("attack_stance_selected")

func _on_defense_button_pressed():
	emit_signal("defense_stance_selected")

func _on_dodge_button_pressed():
	emit_signal("dodge_stance_selected")

func _on_skill_1_button_pressed():
	emit_signal("skill_1_used")

func _on_skill_2_button_pressed():
	emit_signal("skill_2_used")

func _on_inventory_button_pressed():
	emit_signal("inventory_opened")

func _on_destiny_design_button_pressed():
	emit_signal("destiny_design_opened")

func _on_map_button_pressed():
	emit_signal("map_requested")

func _on_start_combat_button_pressed():
	emit_signal("start_combat_requested")

func _on_character_damage_taken(amount: int, position: Vector2, is_player_character: bool):
	if not damage_popup_scene:
		printerr("BattleHUD: damage_popup_scene is not set!")
		return

	var popup_instance = damage_popup_scene.instantiate()
	add_child(popup_instance)
	popup_instance.set_damage_text(amount, is_player_character)
	popup_instance.set_start_position(position)

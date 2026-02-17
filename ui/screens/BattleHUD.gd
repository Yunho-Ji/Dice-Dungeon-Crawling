extends CanvasLayer

signal attack_stance_selected
signal defense_stance_selected
signal skill_1_used
signal skill_2_used
signal inventory_opened
signal destiny_design_opened
signal map_requested
signal start_combat_requested

@onready var destiny_design_button = $DestinyDesignButton
@export var map_button: Button
@export var start_combat_button: Button
@export var damage_popup_scene: PackedScene

func _ready():
	print("DEBUG BattleHUD: _ready called.")
	print("DEBUG BattleHUD: destiny_design_button is ", "valid" if is_instance_valid(destiny_design_button) else "NULL")
	print("DEBUG BattleHUD: map_button is ", "valid" if is_instance_valid(map_button) else "NULL")
	print("DEBUG BattleHUD: start_combat_button is ", "valid" if is_instance_valid(start_combat_button) else "NULL")

	$BattleControls/AttackButton.pressed.connect(_on_attack_button_pressed)
	$BattleControls/DefenseButton.pressed.connect(_on_defense_button_pressed)
	$BattleControls/Skill1Button.pressed.connect(_on_skill_1_button_pressed)
	$BattleControls/Skill2Button.pressed.connect(_on_skill_2_button_pressed)
	# $InventoryButton.pressed.connect(_on_inventory_button_pressed) # Connected in editor
	
	# [수정] 버튼 시그널 명시적 연결
	if map_button: map_button.pressed.connect(_on_map_button_pressed)
	if start_combat_button: start_combat_button.pressed.connect(_on_start_combat_button_pressed)
	if destiny_design_button: destiny_design_button.pressed.connect(_on_destiny_design_button_pressed)
	
	# InventoryScreen Autoload에 inventory_opened 시그널 연결
	inventory_opened.connect(InventoryScreen.show_screen)

	# Initially hide both buttons
	if map_button: map_button.visible = false
	if start_combat_button: start_combat_button.visible = false

func set_destiny_button_enabled(is_enabled: bool):
	if is_instance_valid(destiny_design_button):
		destiny_design_button.disabled = not is_enabled
		print("DEBUG BattleHUD: destiny_design_button disabled set to ", not is_enabled)
	else:
		printerr("DEBUG BattleHUD: destiny_design_button is invalid in set_destiny_button_enabled.")

func show_map_button():
	if is_instance_valid(map_button):
		map_button.visible = true
		print("DEBUG BattleHUD: map_button set visible to true.")
	else:
		printerr("DEBUG BattleHUD: map_button is invalid in show_map_button.")
	if is_instance_valid(start_combat_button):
		start_combat_button.visible = false
		print("DEBUG BattleHUD: start_combat_button set visible to false.")
	else:
		printerr("DEBUG BattleHUD: start_combat_button is invalid in show_map_button.")

func show_start_combat_button():
	if is_instance_valid(map_button):
		map_button.visible = false
		print("DEBUG BattleHUD: map_button set visible to false.")
	else:
		printerr("DEBUG BattleHUD: map_button is invalid in show_start_combat_button.")
	if is_instance_valid(start_combat_button):
		start_combat_button.visible = true
		print("DEBUG BattleHUD: start_combat_button set visible to true.")
	else:
		printerr("DEBUG BattleHUD: start_combat_button is invalid in show_start_combat_button.")

func _on_attack_button_pressed():
	emit_signal("attack_stance_selected")

func _on_defense_button_pressed():
	emit_signal("defense_stance_selected")

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
	
	# [수정] 복수 공격 시 데미지 숫자가 겹치지 않도록 무작위 오프셋 추가
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-20, 20))
	var final_position = position + random_offset
	
	popup_instance.set_damage_text(amount, is_player_character)
	popup_instance.set_start_position(final_position)

extends Control

@onready var label = $Label

var duration = 1.0 # Duration of the popup
var float_speed = 50.0 # Speed at which the popup floats up

func _ready():
	set_process(true)
	# Start a one-shot timer to queue_free after duration
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(queue_free)

func _process(delta):
	# Float up
	position -= Vector2(0, float_speed * delta)
	
	# Fade out
	modulate.a = lerp(modulate.a, 0.0, delta / duration)

func set_damage_text(amount: int, is_player_damage: bool):
	label.text = str(amount)
	if is_player_damage:
		label.add_theme_color_override("font_color", Color.RED)
	else:
		label.add_theme_color_override("font_color", Color.YELLOW)

func set_start_position(pos: Vector2):
	global_position = pos # Set global position of the Control node


extends Control

@onready var dungeon_progress_bar: ProgressBar = $DungeonProgressBar
@onready var depth_label: Label = $DungeonProgressBar/DepthLabel

func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	self.visible = false


# Updates the progress bar with the current dungeon depth.
func update_progress(current_depth: int, max_depth: int):
	if max_depth > 0:
		dungeon_progress_bar.max_value = max_depth
		dungeon_progress_bar.value = current_depth
		depth_label.text = "%d / %d" % [current_depth, max_depth]
	else:
		dungeon_progress_bar.value = 0
		depth_label.text = ""

func show_hud():
	self.visible = true

func hide_hud():
	self.visible = false

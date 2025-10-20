extends Panel
class_name DungeonMap

signal node_activated(node_id: String)

# Node references
@onready var node_container: Node2D = $NodeContainer
@onready var path_container: Node2D = $PathContainer
@onready var info_label: Label = $InfoLabel
@onready var enter_dungeon_button: Button = $EnterDungeonButton

# Data from MapManager - This will be refreshed in _on_visibility_changed
var dungeon_data: Dictionary
var current_node_id: String
var player_run_state: Dictionary
var dungeon_seed: int = 0
var is_dev_mode: bool = false

var selected_target_node_id: String
var player_marker: ColorRect # Declare as member variable

# Panning & Zooming logic variables
var _is_dragging = false
var _last_mouse_pos: Vector2
var _zoom_speed = 1.1
var _max_zoom = 2.0
var _min_zoom = 0.5

var _current_reachable_ids: Array = []

func _ready():
	selected_target_node_id = ""
	enter_dungeon_button.disabled = true
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_button_pressed)
	
	_create_player_marker()
	
	await get_tree().process_frame
	_draw_map()
	_update_map_visuals()

	# Center the camera on the player marker
	if dungeon_data.nodes.has(current_node_id):
		var player_node_pos = dungeon_data.nodes[current_node_id].position
		var screen_center = get_viewport_rect().size / 2.0
		
		var target_pos = screen_center - (player_node_pos * node_container.scale)
		
		node_container.position = target_pos
		path_container.position = target_pos


func _create_player_marker():
	player_marker = ColorRect.new()
	player_marker.size = Vector2(20, 20)
	player_marker.color = Color.RED
	player_marker.position = Vector2(-10, -10)
	node_container.add_child(player_marker)
	player_marker.visible = false

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_is_dragging = true
				_last_mouse_pos = event.position
			else:
				_is_dragging = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_scale = node_container.scale * _zoom_speed
			if new_scale.x <= _max_zoom:
				node_container.scale = new_scale
				path_container.scale = new_scale
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_scale = node_container.scale / _zoom_speed
			if new_scale.x >= _min_zoom:
				node_container.scale = new_scale
				path_container.scale = new_scale
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _last_mouse_pos
		node_container.position += delta
		path_container.position += delta
		_last_mouse_pos = event.position

func _clear_map():
	for child in node_container.get_children():
		if child != player_marker:
			child.queue_free()
	for child in path_container.get_children():
		child.queue_free()

func _draw_map():
	if not dungeon_data or not dungeon_data.has("nodes") or not dungeon_data.has("paths"):
		return

	_clear_map()

	for path_data in dungeon_data.paths:
		var line = Line2D.new()
		line.name = "%s-%s" % [path_data.from, path_data.to]
		line.points = path_data.points
		line.width = 3.0
		line.default_color = Color.GRAY
		path_container.add_child(line)

	for node_id in dungeon_data.nodes:
		var node_data: DungeonNode = dungeon_data.nodes[node_id]
		var node_visual = Node2D.new()
		node_visual.name = node_id
		node_visual.position = node_data.position
		
		var label = Label.new()
		label.text = "%s\n(%s)" % [node_data.node_type.capitalize(), node_data.depth]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-50, -40)
		label.size = Vector2(100, 40)
		node_visual.add_child(label)
		
		var button = Button.new()
		button.text = "Select"
		button.size = Vector2(80, 30)
		button.position = Vector2(-40, 0)
		button.name = "SelectButton"
		button.pressed.connect(Callable(self, "_on_node_selected").bind(node_id))
		node_visual.add_child(button)
		
		node_container.add_child(node_visual)

func _get_nodes_in_range(start_node_id: String, range_limit: int) -> Array[String]:
	if not dungeon_data.nodes.has(start_node_id):
		return []

	var nodes_in_range: Array[String] = []
	var queue = [{ "id": start_node_id, "dist": 0 }]
	var visited_for_bfs = { start_node_id: true }

	var head = 0
	while head < queue.size():
		var current = queue[head]
		head += 1

		var current_id = current.id
		var current_dist = current.dist

		if current_dist > range_limit:
			continue

		nodes_in_range.append(current_id)

		var current_node_data = dungeon_data.nodes[current_id]
		for next_id in current_node_data.next_node_ids:
			if not next_id in visited_for_bfs:
				visited_for_bfs[next_id] = true
				queue.append({ "id": next_id, "dist": current_dist + 1 })
	return nodes_in_range

func _update_map_visuals():
	var visible_node_ids = {}
	var is_dev = is_dev_mode

	if not is_dev:
		for node_id in player_run_state.VisitedNodeIDs:
			visible_node_ids[node_id] = true
		var vision_range = player_run_state.get("vision_range", 1)
		var nodes_in_range = _get_nodes_in_range(current_node_id, vision_range)
		for node_id in nodes_in_range:
			visible_node_ids[node_id] = true

	for node_visual in node_container.get_children():
		if node_visual == player_marker: continue

		if node_visual.has_meta("fading_in"):
			continue
		
		var node_id = node_visual.name
		var should_be_visible = is_dev or (node_id in visible_node_ids)

		var target_color = Color.WHITE
		if player_run_state.VisitedNodeIDs.has(node_id):
			target_color = Color(0.5, 0.5, 0.5)
		if node_id == selected_target_node_id:
			target_color = Color.AQUAMARINE

		if should_be_visible:
			node_visual.visible = true
			if node_visual.modulate.a < 0.1:
				node_visual.set_meta("fading_in", true)
				node_visual.modulate = target_color
				node_visual.modulate.a = 0
				var tween = create_tween()
				tween.tween_property(node_visual, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
				tween.tween_callback(func(): 
					if is_instance_valid(node_visual): 
						node_visual.remove_meta("fading_in")
				)
			else:
				node_visual.modulate = target_color
		else:
			node_visual.visible = false
			node_visual.modulate.a = 0

	for path_line in path_container.get_children():
		if is_dev:
			path_line.visible = true
		else:
			var ids = path_line.name.split("-")
			if ids.size() < 2: continue
			path_line.visible = (ids[0] in visible_node_ids) and (ids[1] in visible_node_ids)

	_update_button_states()
	_update_info_label()
	_update_player_marker()

func _update_button_states():
	_current_reachable_ids.clear()
	print("DEBUG: _update_button_states called. current_node_id: ", current_node_id)

	if dungeon_data.nodes.has(current_node_id):
		var player_node: DungeonNode = dungeon_data.nodes[current_node_id]
		_current_reachable_ids = player_node.next_node_ids.duplicate()
		print("DEBUG: Reachable IDs from ", current_node_id, ": ", _current_reachable_ids)

	var visited_ids = player_run_state.VisitedNodeIDs

	for node_visual in node_container.get_children():
		var button = node_visual.find_child("SelectButton")
		if button:
			var node_id = node_visual.name
			var is_reachable = node_id in _current_reachable_ids
			var is_visited = node_id in visited_ids
			button.disabled = not is_reachable or is_visited
			print("DEBUG: Node ", node_id, ": is_reachable = ", is_reachable, ", is_visited = ", is_visited, ", button.disabled = ", button.disabled)

func _update_info_label():
	var info_text = "Dungeon Seed: %s\n" % dungeon_seed
	if not dungeon_data.nodes.has(selected_target_node_id):
		info_text += "Select a destination.\n"
	else:
		var info_node: DungeonNode = dungeon_data.nodes[selected_target_node_id]
		info_text += "Selected: %s (Depth: %d, Type: %s)\n" % [info_node.node_id, info_node.depth, info_node.node_type]
	
	if dungeon_data.nodes.has(current_node_id):
		var current_node_data: DungeonNode = dungeon_data.nodes[current_node_id]
		info_text += "Current: %s (Depth: %d, Type: %s)" % [current_node_data.node_id, current_node_data.depth, current_node_data.node_type]

	info_label.text = info_text

func _update_player_marker():
	if is_instance_valid(player_marker) and dungeon_data.nodes.has(current_node_id):
		var current_node_visual = node_container.get_node(current_node_id)
		if is_instance_valid(current_node_visual):
			player_marker.global_position = current_node_visual.global_position
			player_marker.visible = true
		else:
			player_marker.visible = false
	else:
		player_marker.visible = false

func _on_node_selected(target_node_id: String):
	if target_node_id in _current_reachable_ids:
		selected_target_node_id = target_node_id
		_update_map_visuals()
		enter_dungeon_button.disabled = false
	else:
		print("DEBUG: Attempted to select unreachable node: ", target_node_id)
		selected_target_node_id = ""
		enter_dungeon_button.disabled = true

func _on_enter_dungeon_button_pressed():
	print("DEBUG: 'Enter Dungeon' button pressed. selected_target_node_id: '", selected_target_node_id, "'. Button disabled state: ", enter_dungeon_button.disabled)
	emit_signal("node_activated", selected_target_node_id)

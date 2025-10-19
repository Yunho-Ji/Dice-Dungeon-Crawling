

extends Panel
class_name DungeonMap

signal node_activated(node_id: String)

@onready var graph_edit: GraphEdit = $GraphEdit
@onready var info_label: Label = $InfoLabel
@onready var enter_dungeon_button: Button = $EnterDungeonButton

# These variables will be set by GameManager
var dungeon_map_data: Dictionary
var current_node_id: String # Player's actual position
var player_run_state: Dictionary
var player_current_depth: int # Received from MapManager

var selected_target_node_id: String # The node the player has clicked on

func _ready():
	selected_target_node_id = "" # Initialize to empty string
	enter_dungeon_button.disabled = true
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_button_pressed)
	
	_draw_map()
	_update_node_visuals()
	_update_button_states()
	_update_info_label()

func _draw_map():
	print("DEBUG: _draw_map: dungeon_map_data type: ", typeof(dungeon_map_data))
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	
	for node_id in dungeon_map_data:
		print("DEBUG: _draw_map: node_id: ", node_id, ", type of dungeon_map_data[node_id]: ", typeof(dungeon_map_data[node_id]))
		var dungeon_node: DungeonNode = dungeon_map_data[node_id]
		var graph_node = GraphNode.new()
		graph_node.title = dungeon_node.node_type.capitalize()
		graph_node.name = dungeon_node.node_id
		graph_node.position_offset = dungeon_node.position
		graph_node.set_slot(0, true, TYPE_VECTOR2, Color.WHITE, true, TYPE_VECTOR2, Color.WHITE)

		var button = Button.new()
		button.text = "선택"
		button.name = "SelectButton"
		button.pressed.connect(Callable(self, "_on_graph_node_button_pressed").bind(dungeon_node.node_id))
		graph_node.add_child(button)
		
		graph_edit.add_child(graph_node)
	
	for node_id in dungeon_map_data:
		var dungeon_node: DungeonNode = dungeon_map_data[node_id]
		for next_node_id in dungeon_node.next_node_ids:
			graph_edit.connect_node(dungeon_node.node_id, 0, next_node_id, 0)

func _update_node_visuals():
	var visited_ids = player_run_state.VisitedNodeIDs

	for child in graph_edit.get_children():
		if child is GraphNode:
			var node_data: DungeonNode = dungeon_map_data[child.name]
			# Reset title and color first
			child.title = node_data.node_type.capitalize()
			child.modulate = Color.WHITE
			child.mouse_filter = Control.MOUSE_FILTER_STOP # Default to interactive

			# Apply styles based on state
			var is_in_previous_layer = node_data.depth < player_current_depth

			if is_in_previous_layer:
				child.modulate = Color(0.2, 0.2, 0.2) # Very dark grey for previous layers
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE # Disable interaction
			elif visited_ids.has(child.name):
				child.modulate = Color(0.5, 0.5, 0.5) # Visited (lighter grey)

			if node_data.is_shortcut:
				child.title = "[지름길] " + child.title
				child.modulate = Color.LIME_GREEN # Distinct color for shortcut nodes

			if child.name == selected_target_node_id and child.name != current_node_id:
				child.modulate = Color.AQUAMARINE # Newly Selected
			
			if child.name == current_node_id:
				child.modulate = Color.GOLD # Current Position
				child.title = "[현재위치] " + child.title

func _update_button_states():
	if not dungeon_map_data.has(current_node_id) and current_node_id != "": # Handle initial state where current_node_id is empty
		print("DEBUG: _update_button_states: current_node_id (", current_node_id, ") not in dungeon_map_data.")
		return

	var player_node: DungeonNode = null
	var reachable_ids = []

	if current_node_id != "": # If a start node has been chosen
		player_node = dungeon_map_data[current_node_id]
		reachable_ids = player_node.next_node_ids
	else: # If no start node chosen yet, reachable_ids should be populated with start nodes
		for node_id in dungeon_map_data:
			var node_data: DungeonNode = dungeon_map_data[node_id]
			if node_data.node_type == "start":
				reachable_ids.append(node_id)
	
	print("DEBUG: _update_button_states: current_node_id = ", current_node_id, ", player_current_depth = ", player_current_depth, ", reachable_ids = ", reachable_ids)

	for child in graph_edit.get_children():
		if child is GraphNode:
			var button = child.find_child("SelectButton")
			if button:
				var node_data: DungeonNode = dungeon_map_data[child.name]
				var is_in_previous_layer = node_data.depth < player_current_depth
				var is_start_node = (node_data.node_type == "start")
				var is_node_reachable = false # Renamed to avoid conflict with outer reachable_ids

				if current_node_id == "": # If no start node chosen yet, only start nodes are selectable
					is_node_reachable = is_start_node
				else: # A start node has been chosen, apply normal reachability logic
					is_node_reachable = reachable_ids.has(child.name)

				button.disabled = (not is_node_reachable) or is_in_previous_layer
				print("DEBUG: Node ", child.name, " (Depth: ", node_data.depth, ", Type: ", node_data.node_type, "): is_reachable = ", is_node_reachable, ", is_in_previous_layer = ", is_in_previous_layer, ", is_start_node = ", is_start_node, ", button.disabled = ", button.disabled)

func _update_info_label():
	var node_to_show = selected_target_node_id
	if not dungeon_map_data.has(node_to_show):
		return
	var info_node: DungeonNode = dungeon_map_data[node_to_show]
	info_label.text = "선택된 노드: " + info_node.node_id + " (Depth: " + str(info_node.depth) + ")"
	info_label.text += "\n타입: " + str(info_node.node_type)

func _on_graph_node_button_pressed(target_node_id: String):
	print("DEBUG: _on_graph_node_button_pressed: target_node_id = ", target_node_id)

	var is_target_reachable = false
	var target_node_data: DungeonNode = dungeon_map_data[target_node_id]

	if current_node_id == "": # If no start node chosen yet, check if target is a start node
		if target_node_data.node_type == "start":
			is_target_reachable = true
	else: # A start node has been chosen, apply normal reachability logic
		var player_node: DungeonNode = dungeon_map_data[current_node_id]
		var reachable_ids = player_node.next_node_ids
		is_target_reachable = reachable_ids.has(target_node_id)
		print("DEBUG: _on_graph_node_button_pressed: current_node_id = ", current_node_id, ", reachable_ids = ", reachable_ids)


	if is_target_reachable:
		selected_target_node_id = target_node_id
		_update_info_label()
		_update_node_visuals()
		enter_dungeon_button.disabled = false
		print("DEBUG: _on_graph_node_button_pressed: Node selected: ", selected_target_node_id)
	else:
		print("DEBUG: _on_graph_node_button_pressed: Node not reachable: ", target_node_id)
		enter_dungeon_button.disabled = true

func _on_enter_dungeon_button_pressed():
	emit_signal("node_activated", selected_target_node_id)



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

var selected_target_node_id: String # The node the player has clicked on

func _ready():
	selected_target_node_id = current_node_id
	enter_dungeon_button.disabled = true
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_button_pressed)
	
	_draw_map()
	_update_node_visuals()
	_update_button_states()
	_update_info_label()

func _draw_map():
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	
	for node_id in dungeon_map_data:
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
	var player_node_data: DungeonNode = dungeon_map_data[current_node_id]

	for child in graph_edit.get_children():
		if child is GraphNode:
			var node_data: DungeonNode = dungeon_map_data[child.name]
			# Reset title and color first
			child.title = node_data.node_type.capitalize()
			child.modulate = Color.WHITE
			child.mouse_filter = Control.MOUSE_FILTER_STOP # Default to interactive

			# Apply styles based on state
			var is_in_previous_layer = node_data.depth < player_node_data.depth

			if is_in_previous_layer:
				child.modulate = Color(0.2, 0.2, 0.2) # Very dark grey for previous layers
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE # Disable interaction
			elif visited_ids.has(child.name):
				child.modulate = Color(0.5, 0.5, 0.5) # Visited (lighter grey)

			if child.name == selected_target_node_id and child.name != current_node_id:
				child.modulate = Color.AQUAMARINE # Newly Selected
			
			if child.name == current_node_id:
				child.modulate = Color.GOLD # Current Position
				child.title = "[현재위치] " + child.title

func _update_button_states():
	if not dungeon_map_data.has(current_node_id):
		return
	var player_node: DungeonNode = dungeon_map_data[current_node_id]
	var reachable_ids = player_node.next_node_ids

	for child in graph_edit.get_children():
		if child is GraphNode:
			var button = child.find_child("SelectButton")
			if button:
				var node_data: DungeonNode = dungeon_map_data[child.name]
				var is_in_previous_layer = node_data.depth < player_node.depth

				# A button is enabled ONLY if its node is in the reachable list AND not in a previous layer.
				button.disabled = (not reachable_ids.has(child.name)) or is_in_previous_layer

func _update_info_label():
	var node_to_show = selected_target_node_id
	if not dungeon_map_data.has(node_to_show):
		return
	var info_node: DungeonNode = dungeon_map_data[node_to_show]
	info_label.text = "선택된 노드: " + info_node.node_id + " (Depth: " + str(info_node.depth) + ")"
	info_label.text += "\n타입: " + str(info_node.node_type)

func _on_graph_node_button_pressed(target_node_id: String):
	selected_target_node_id = target_node_id
	_update_info_label()
	_update_node_visuals()
	enter_dungeon_button.disabled = false
	print("선택된 노드: ", selected_target_node_id)

func _on_enter_dungeon_button_pressed():
	emit_signal("node_activated", selected_target_node_id)

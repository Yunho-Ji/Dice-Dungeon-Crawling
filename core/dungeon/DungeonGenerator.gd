extends Node
class_name DungeonGenerator

var _rng = RandomNumberGenerator.new()

func _seeded_shuffle(array: Array) -> void:
	var size = array.size()
	for i in range(size - 1, 0, -1):
		var j = _rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp

func generate_dungeon(config: Dictionary, seed_value: int = 0) -> Dictionary:
	# --- 0. Setup ---
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

	var max_layers = _rng.randi_range(config.min_layers, config.max_layers)
	var grid_width = 7
	
	var potential_nodes = {}
	var paths = []

	# --- 1. Grid Initialization ---
	for y in range(max_layers):
		for x in range(grid_width):
			var node_id = "node_%d_%d" % [y, x]
			var pos = Vector2(250 * y + 100, 150 * (x - (grid_width - 1) / 2.0) + 300)
			var node = DungeonNode.new(node_id, "", y, pos)
			potential_nodes[Vector2i(x, y)] = node

	# --- 2. Determine Final Boss Endpoint ---
	var boss_x = _rng.randi_range(0, grid_width - 1)
	var real_boss_node = potential_nodes[Vector2i(boss_x, max_layers - 1)]
	real_boss_node.node_type = "boss"

	# --- 3. Path Generation (Reverse from the single boss) ---
	var start_nodes = []
	for i in range(6):
		var path = []
		var current_node = real_boss_node
		path.append(current_node)

		for y in range(max_layers - 2, -1, -1):
			var current_x = int(round((current_node.position.y - 300) / 150.0 + (grid_width - 1) / 2.0))
			var parent_candidates = []
			for offset in [-2, -1, 0, 1, 2]:
				var parent_x = current_x + offset
				if parent_x >= 0 and parent_x < grid_width:
					parent_candidates.append(potential_nodes[Vector2i(parent_x, y)])
			
			if parent_candidates.is_empty():
				path.clear()
				break

			var parent_node = parent_candidates[_rng.randi_range(0, parent_candidates.size() - 1)]
			# Avoid duplicate connections
			if not parent_node.next_node_ids.has(current_node.node_id):
				parent_node.next_node_ids.append(current_node.node_id)
			path.append(parent_node)
			current_node = parent_node
		
		if path.is_empty(): continue

		start_nodes.append(current_node)
		paths.append(path)

	# --- 4. Finalize Nodes and Paths ---
	var final_nodes = {}
	for path in paths:
		for node in path:
			if not final_nodes.has(node.node_id):
				final_nodes[node.node_id] = node

	# Set node types
	var intermediate_nodes = []
	for node in final_nodes.values():
		if node.depth == 0:
			node.node_type = "start"
		elif node.node_type != "boss": # Only boss is pre-set
			node.node_type = "battle"
			intermediate_nodes.append(node)

	# Place Fake Bosses on the second to last layer
	var second_to_last_layer_candidates = []
	for node in intermediate_nodes:
		if node.depth == max_layers - 2:
			second_to_last_layer_candidates.append(node)
	
	_seeded_shuffle(second_to_last_layer_candidates)
	var num_fake_bosses = config.get("num_fake_bosses", 2)
	
	for i in range(min(num_fake_bosses, second_to_last_layer_candidates.size())):
		var fake_boss_node = second_to_last_layer_candidates.pop_front()
		fake_boss_node.node_type = "fake_boss"
		# Ensure fake bosses connect to the real boss
		if not fake_boss_node.next_node_ids.has(real_boss_node.node_id):
			fake_boss_node.next_node_ids.append(real_boss_node.node_id)

	# Place Elite and Special nodes from remaining intermediate nodes
	# Filter out nodes that became fake bosses
	intermediate_nodes = intermediate_nodes.filter(func(node): return node.node_type == "battle")
	_seeded_shuffle(intermediate_nodes)
	var num_elites = config.get("num_elites", 2)
	var num_specials = config.get("num_specials", 2)
	
	for i in range(min(num_elites, intermediate_nodes.size())):
		intermediate_nodes.pop_front().node_type = "elite"
	
	for i in range(min(num_specials, intermediate_nodes.size())):
		intermediate_nodes.pop_front().node_type = "special"

	# --- 5. Generate Visual Path Geometry ---
	var visual_paths = []
	var visited_edges = {}
	for node in final_nodes.values():
		for next_node_id in node.next_node_ids:
			var edge_id = "%s-%s" % [node.node_id, next_node_id]
			if visited_edges.has(edge_id): continue
			visited_edges[edge_id] = true

			if not final_nodes.has(next_node_id):
				print("Error: Path points to a non-existent node: ", next_node_id)
				continue
			var to_node = final_nodes[next_node_id]
			var from_pos = node.position
			var to_pos = to_node.position
			
			var distance = from_pos.distance_to(to_pos)
			var num_points = int(distance / 20.0)
			var points = PackedVector2Array()
			
			var direction = (to_pos - from_pos).normalized()
			var perpendicular = direction.orthogonal()
			
			points.append(from_pos)
			for i in range(1, num_points):
				var t = float(i) / num_points
				var point = from_pos.lerp(to_pos, t)
				
				var wobble = _rng.randf_range(-15.0, 15.0)
				point += perpendicular * wobble
				
				points.append(point)
			points.append(to_pos)
			
			visual_paths.append({"from": node.node_id, "to": next_node_id, "points": points})

	return {"nodes": final_nodes, "paths": visual_paths, "num_layers": max_layers}

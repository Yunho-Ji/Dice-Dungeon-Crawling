
extends Node
class_name DungeonGenerator

# const DungeonNode = preload("res://core/dungeon/DungeonNode.gd") # Removed to fix warning

@export var num_layers = 7
@export var nodes_per_layer = 3
@export var branching_factor = 0.5

func generate_dungeon(config: Dictionary) -> Dictionary:
	# Use config to determine dungeon parameters
	var actual_num_layers = randi_range(config.min_layers, config.max_layers)
	var actual_special_node_count = config.special_node_count
	var actual_has_elites = config.has_elites

	var all_nodes = {}
	var current_layer_nodes: Array[DungeonNode] = []
	var placed_shortcut_node: DungeonNode = null # Declare here

	# --- Create multiple start nodes (Depth 0) ---
	var num_start_nodes = randi_range(1, 3) # 1 to 3 starting nodes
	for j in range(num_start_nodes):
		var node_id = "start_%d" % j
		var node_pos = Vector2(50, 150 * (j - (num_start_nodes - 1) / 2.0) + 300)
		var start_node = DungeonNode.new(node_id, "start", 0, node_pos)
		all_nodes[node_id] = start_node
		current_layer_nodes.append(start_node)

	for i in range(1, actual_num_layers):
		var next_layer_nodes_map = {}
		var num_nodes_in_layer = randi_range(2, nodes_per_layer)

		for j in range(num_nodes_in_layer):
			var node_id = "node_%d_%d" % [i, j]
			var node_type = "battle" # Default type
			var node_pos = Vector2(200 * i + 50, 150 * (j - (num_nodes_in_layer - 1) / 2.0) + 300)
			var new_node = DungeonNode.new(node_id, node_type, i, node_pos)
			next_layer_nodes_map[node_id] = new_node
			all_nodes[node_id] = new_node

		# Connect current layer to the next layer in a structured way
		var next_layer_nodes = next_layer_nodes_map.values()
		for j in range(len(current_layer_nodes)):
			var prev_node = current_layer_nodes[j]
			
			var num_nodes_in_next_layer = len(next_layer_nodes)
			var target_mid_point = float(j) / len(current_layer_nodes) * num_nodes_in_next_layer
			
			var start_index = max(0, int(target_mid_point - 1))
			var end_index = min(num_nodes_in_next_layer, int(target_mid_point + 2))
			
			var candidates = next_layer_nodes.slice(start_index, end_index)
			if candidates.is_empty():
				candidates = next_layer_nodes

			candidates.shuffle()
			
			var num_connections = 1
			if randf() < branching_factor:
				num_connections = min(2, len(candidates))

			for k in range(num_connections):
				var child_node = candidates[k]
				if not prev_node.next_node_ids.has(child_node.node_id):
					prev_node.next_node_ids.append(child_node.node_id)

		# Ensure all nodes in the next layer have at least one parent
		for next_node in next_layer_nodes:
			var has_parent = false
			for node_id in all_nodes:
				if all_nodes[node_id].next_node_ids.has(next_node.node_id):
					has_parent = true
					break
			if not has_parent:
				var closest_prev_node = current_layer_nodes[0]
				var min_dist = INF
				for prev_node in current_layer_nodes:
					var dist = prev_node.position.distance_to(next_node.position)
					if dist < min_dist:
						min_dist = dist
						closest_prev_node = prev_node
				if not closest_prev_node.next_node_ids.has(next_node.node_id):
					closest_prev_node.next_node_ids.append(next_node.node_id)

		var next_layer_nodes_array: Array[DungeonNode] = []
		for node in next_layer_nodes_map.values():
			next_layer_nodes_array.append(node)
		
		current_layer_nodes = next_layer_nodes_array

	# --- NEW: Make all nodes in the last layer boss nodes ---
	for node_id in all_nodes:
		var node = all_nodes[node_id]
		if node.depth == actual_num_layers - 1:
			node.node_type = "boss"
	# --- END NEW ---

	# --- Place Special Nodes and Elites ---
	var non_start_boss_nodes = []
	for node_id in all_nodes:
		var node = all_nodes[node_id]
		if node.node_type != "start" and node.node_type != "boss":
			non_start_boss_nodes.append(node)

	non_start_boss_nodes.shuffle()

	# Place Special Nodes first
	var special_node_candidates = non_start_boss_nodes.duplicate()
	
	# --- TEMPORARY: Ensure at least one special node for testing ---
	var temp_actual_special_node_count = actual_special_node_count
	if temp_actual_special_node_count == 0 and not special_node_candidates.is_empty():
		temp_actual_special_node_count = 1
	# --- END TEMPORARY ---

	for i in range(min(temp_actual_special_node_count, special_node_candidates.size())):
		var node = special_node_candidates[i]
		# --- TEMPORARY: Force first special node to be rest/shop for testing ---
		if i == 0:
			node.node_type = ["rest", "shop"][randi() % 2] # Force it to be one of these
		else:
			# Randomly assign rest or shop for subsequent special nodes
			node.node_type = ["rest", "shop"][randi() % 2]
		# --- END TEMPORARY ---

	# Place Elite Nodes (only convert remaining 'battle' nodes)
	if actual_has_elites:
		var elite_candidates = []
		for node in non_start_boss_nodes:
			if node.node_type == "battle": # Only convert battle nodes to elite
				elite_candidates.append(node)
		elite_candidates.shuffle()
		
		# Place a few elite nodes (e.g., 1-2 elites per dungeon)
		var num_elites_to_place = randi_range(1, 2)
		for i in range(min(num_elites_to_place, elite_candidates.size())):
			elite_candidates[i].node_type = "elite"

	# --- Place Shortcut Node (0-1 per dungeon) ---
	var shortcut_candidates = []
	for node_id in all_nodes:
		var node = all_nodes[node_id]
		# Only consider battle nodes that are not start, boss, rest, shop, or elite
		if node.node_type == "battle" and node.depth > 0 and node.depth < actual_num_layers - 1: # Not start/boss layer
			shortcut_candidates.append(node)
	
	shortcut_candidates.shuffle()
	
	if not shortcut_candidates.is_empty() and randf() < 0.5: # 50% chance to place a shortcut node
		var shortcut_node = shortcut_candidates[0]
		shortcut_node.is_shortcut = true
		shortcut_node.skip_layers = int(actual_num_layers * 0.25)
		print("DungeonGenerator: Shortcut node placed at ", shortcut_node.node_id, " (skips ", shortcut_node.skip_layers, " layers)")

	# --- Handle Shortcut Node Connections (Diagonal) ---
	if placed_shortcut_node:
		placed_shortcut_node.next_node_ids.clear() # Clear existing connections

		var target_layer_depth = placed_shortcut_node.depth + placed_shortcut_node.skip_layers
		target_layer_depth = min(target_layer_depth, actual_num_layers - 1) # Don't skip beyond last layer

		var target_layer_nodes = []
		for node_id in all_nodes:
			var node = all_nodes[node_id]
			if node.depth == target_layer_depth:
				target_layer_nodes.append(node)
		
		if not target_layer_nodes.is_empty():
			target_layer_nodes.shuffle()
			# Connect to 1-2 nodes in the target layer
			var num_connections = randi_range(1, min(2, target_layer_nodes.size()))
			for k in range(num_connections):
				placed_shortcut_node.next_node_ids.append(target_layer_nodes[k].node_id)
			print("DungeonGenerator: Shortcut node ", placed_shortcut_node.node_id, " connected to layer ", target_layer_depth, " nodes: ", placed_shortcut_node.next_node_ids)
		else:
			printerr("DungeonGenerator: No nodes found in target layer ", target_layer_depth, " for shortcut node ", placed_shortcut_node.node_id)

	return all_nodes


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

	var start_node = DungeonNode.new("start_0", "start", 0, Vector2(50, 300))
	var all_nodes = { "start_0": start_node }
	var final_boss_node = null

	var current_layer_nodes: Array[DungeonNode] = [start_node]

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

		if i == actual_num_layers - 1:
			if len(current_layer_nodes) > 0:
				final_boss_node = current_layer_nodes[randi() % len(current_layer_nodes)]
				final_boss_node.node_type = "boss"

	if not final_boss_node and len(all_nodes) > 1:
		var leaf_nodes = []
		for node in all_nodes.values():
			if not node.next_node_ids:
				leaf_nodes.append(node)
		if leaf_nodes:
			final_boss_node = leaf_nodes[randi() % len(leaf_nodes)]
			final_boss_node.node_type = "boss"

	# --- Place Special Nodes and Elites ---
	var non_start_boss_nodes = []
	for node_id in all_nodes:
		var node = all_nodes[node_id]
		if node.node_type != "start" and node.node_type != "boss":
			non_start_boss_nodes.append(node)

	non_start_boss_nodes.shuffle()

	# Place Special Nodes first
	var special_node_candidates = non_start_boss_nodes.duplicate()
	for i in range(min(actual_special_node_count, special_node_candidates.size())):
		var node = special_node_candidates[i]
		# Randomly assign rest or shop
		node.node_type = ["rest", "shop"][randi() % 2]

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

	return all_nodes

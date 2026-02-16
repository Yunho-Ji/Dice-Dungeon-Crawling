extends Node

# 투사체 관리를 위한 매니저
# 전역적으로 투사체 생성을 요청받고, 적절한 부모 노드에 추가합니다.

func launch_projectile(p_data: Resource, spawn_pos: Vector2, p_target: Node2D, base_damage: int, p_shooter: Node2D) -> Node2D:
	if not p_data or not p_data.get("projectile_scene"):
		printerr("ProjectileManager: 유효하지 않은 투사체 데이터입니다.")
		return null
		
	var projectile = p_data.get("projectile_scene").instantiate()
	
	var container = _get_projectile_container()
	container.add_child(projectile)
	
	projectile.global_position = spawn_pos
	
	if "speed" in projectile:
		projectile.speed = p_data.get("speed")
	
	if "data" in projectile:
		projectile.set("data", p_data)
	
	var multiplier = p_data.get("damage_multiplier")
	if multiplier == null: multiplier = 1.0
	
	var final_damage = int(base_damage * multiplier)
	
	var piercing_rate = 0.0
	var true_damage_rate = 0.0
	if p_shooter and p_shooter.get("current_stats"):
		var p_stat = p_shooter.current_stats.get_stat("piercing")
		if p_stat: piercing_rate = p_stat.computed_value
		var t_stat = p_shooter.current_stats.get_stat("true_damage")
		if t_stat: true_damage_rate = t_stat.computed_value

	if projectile.has_method("launch"):
		projectile.launch(p_target, final_damage, p_shooter, piercing_rate, true_damage_rate)
	
	return projectile

func spawn_projectile(projectile_scene: PackedScene, spawn_pos: Vector2, p_target: Node2D, damage: int, p_shooter: Node2D) -> Node2D:
	if not projectile_scene:
		printerr("ProjectileManager: 유효하지 않은 투사체 씬입니다.")
		return null
		
	var projectile = projectile_scene.instantiate()
			
	var container = _get_projectile_container()
	container.add_child(projectile)
	
	projectile.global_position = spawn_pos

	var piercing_rate = 0.0
	var true_damage_rate = 0.0
	if p_shooter and p_shooter.get("current_stats"):
		var p_stat = p_shooter.current_stats.get_stat("piercing")
		if p_stat: piercing_rate = p_stat.computed_value
		var t_stat = p_shooter.current_stats.get_stat("true_damage")
		if t_stat: true_damage_rate = t_stat.computed_value

	if projectile.has_method("launch"):
		projectile.launch(p_target, damage, p_shooter, piercing_rate, true_damage_rate)
	
	return projectile

func _get_projectile_container() -> Node:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_node("Projectiles"):
		return current_scene.get_node("Projectiles")
	return current_scene if current_scene else get_tree().root

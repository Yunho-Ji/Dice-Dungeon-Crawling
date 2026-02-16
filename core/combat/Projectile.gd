class_name Projectile
extends Node2D

@export var speed: float = 800.0
@export var impact_distance: float = 20.0
@export var target_offset: Vector2 = Vector2(0, -30) # 적의 가슴 부위를 조준하기 위한 오프셋

var target: Node2D = null
var damage: int = 0
var piercing_rate: float = 0.0 # 방어 관통
var true_damage_rate: float = 0.0 # 트루 데미지 (보호막 무시)
var shooter: Node2D = null
var is_active: bool = false
var data: Resource = null # ProjectileData를 직접 참조하면 순환 참조 발생 가능하므로 Resource로 지정

func launch(p_target: Node2D, p_damage: int, p_shooter: Node2D, p_piercing: float = 0.0, p_true_dmg: float = 0.0):
	target = p_target
	damage = p_damage
	piercing_rate = p_piercing
	true_damage_rate = p_true_dmg
	shooter = p_shooter
	is_active = true
	
	# 초기 방향 설정 (오프셋 적용)
	if is_instance_valid(target):
		var target_pos = target.global_position + target_offset
		var direction = (target_pos - global_position).normalized()
		rotation = direction.angle()

func _process(delta):
	if not is_active:
		return
		
	if not is_instance_valid(target):
		_on_target_lost()
		return
		
	var target_pos = target.global_position + target_offset
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta
	
	# 활시위에서 조준한 방향을 유지하며 타겟을 향해 회전 (즉각적인 방향 반영)
	rotation = direction.angle()
	
	# 목표물에 도달했는지 확인
	if global_position.distance_to(target_pos) < impact_distance:
		_on_impact()

func _on_impact():
	is_active = false
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage, piercing_rate, true_damage_rate)
	
	# 임팩트 효과 처리
	if data:
		var vfx = data.get("impact_vfx")
		if vfx:
			_spawn_impact_vfx(vfx)
	
	_handle_cleanup()

func _spawn_impact_vfx(vfx_scene: PackedScene):
	var vfx = vfx_scene.instantiate()
	get_parent().add_child(vfx)
	vfx.global_position = global_position

func _on_target_lost():
	_handle_cleanup()

func _handle_cleanup():
	queue_free()

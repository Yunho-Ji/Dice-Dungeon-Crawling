extends Node2D

# -----------------------------------------------------------------------------
# [테스트] 주사위 물리 및 겹침 방지 테스트 매니저
# -----------------------------------------------------------------------------

@export var dice_scene: PackedScene
@export var dice_types: Array[int] = [6, 6, 20, 20] # 테스트할 주사위 종류

var spawned_dice: Array = []

func _ready():
	# 화면 경계 (바닥) 생성
	_create_bounds()
	
	# 초기화 후 1초 뒤에 주사위 투척
	await get_tree().create_timer(1.0).timeout
	spawn_and_throw()

func _create_bounds():
	var screen_size = get_viewport_rect().size
	var bounds = StaticBody2D.new()
	add_child(bounds)
	
	# 사방 벽 (CollisionShape2D)
	var shapes = [
		Rect2(0, screen_size.y, screen_size.x, 20), # 바닥
		Rect2(0, -20, screen_size.x, 20),           # 천장
		Rect2(-20, 0, 20, screen_size.y),           # 왼쪽
		Rect2(screen_size.x, 0, 20, screen_size.y)  # 오른쪽
	]
	
	for rect in shapes:
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		col.position = rect.position + rect.size / 2
		bounds.add_child(col)

func spawn_and_throw():
	# 기존 주사위 제거
	for d in spawned_dice:
		if is_instance_valid(d):
			d.queue_free()
	spawned_dice.clear()
	
	# 화면 중앙 (Camera2D가 중앙이므로 0,0 부근)
	var spawn_origin = Vector2.ZERO
	
	for sides in dice_types:
		var dice = dice_scene.instantiate() as PhysicalDice
		add_child(dice)
		dice.dice_sides = sides
		dice.position = spawn_origin + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		
		# 랜덤한 방향과 회전력으로 투척
		var force = Vector2(randf_range(-800, 800), randf_range(-800, 800))
		var torque = randf_range(-2000, 2000)
		
		dice.throw(force, torque)
		spawned_dice.append(dice)

func _input(event):
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		spawn_and_throw()
		print("테스트 재시작 (R) - [개발자 모드]")

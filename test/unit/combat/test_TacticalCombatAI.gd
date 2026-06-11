extends "res://addons/gut/test.gd"

# Tactical Environment & Smart AI Behavior Test
# 목표: 타일(함정) 가중치를 고려한 패스파인딩, 강제 이동(넉백/그랩) 및 그로 인한 환경 상호작용 검증

var CharacterClass = load("res://characters/Character.gd")
var player: Character = null
var enemy: Character = null
var grid_manager = null # 가상의 HexGridManager

func before_each():
	# 1. 가상의 HexGridManager 세팅 (AStarGrid2D 래핑)
	grid_manager = Node2D.new()
	grid_manager.name = "HexGridManager"
	_setup_mock_grid_manager(grid_manager)
	add_child(grid_manager)

	# 2. 플레이어 및 적 개체 생성
	player = CharacterClass.new()
	player.name = "Player"
	_setup_dummy_nodes(player)
	player.current_stats = MyCharacterStats.new()
	player.current_stats.health.base_value = 100
	player.current_stats.health.current_value = 100
	player.grid_manager = grid_manager
	add_child(player)

	enemy = CharacterClass.new()
	enemy.name = "Enemy"
	_setup_dummy_nodes(enemy)
	enemy.current_stats = MyCharacterStats.new()
	enemy.current_stats.health.base_value = 50
	enemy.current_stats.health.current_value = 50
	enemy.grid_manager = grid_manager
	add_child(enemy)

	player.grid_pos = Vector2i(0, 0)
	enemy.grid_pos = Vector2i(3, 0)

func after_each():
	if is_instance_valid(player): player.free()
	if is_instance_valid(enemy): enemy.free()
	if is_instance_valid(grid_manager): grid_manager.free()

func _setup_dummy_nodes(c):
	var pb = ProgressBar.new()
	pb.name = "ProgressBar"
	c.add_child(pb)
	var lb = Label.new()
	lb.name = "Label"
	c.add_child(lb)

func _setup_mock_grid_manager(gm: Node):
	# AStarGrid2D 속성을 직접 스크립트 변수로 모방합니다.
	gm.set_script(load("res://core/combat/HexGridManager.gd"))
	gm._initialize_grid()
	
	# 테스트를 위해 Mock 함수들을 덮어씌웁니다. (동적 기능 추가)
	# 원래 HexGridManager.gd 에는 가중치(Weight) 지원이 없으나 이번 Build 2에서 추가될 내용입니다.
	if not gm.astar.has_method("set_point_weight_scale"):
		print("Warning: AStarGrid2D does not have set_point_weight_scale. Testing basic bounds.")

# ----------------------------------------------------------------------
# [Build 1 & 2] 타일 속성(함정) 및 가중치를 고려한 패스파인딩 테스트
# ----------------------------------------------------------------------
func test_pathfinding_avoids_traps():
	# 시나리오: (0,0)에 있는 플레이어가 (3,0)에 있는 적에게 가려고 합니다.
	# 하지만 직선 경로인 (1,0), (2,0) 에 치명적인 함정이 깔려 있습니다.
	
	# 1. 함정 설치 (가중치를 매우 높게 설정하여 우회 유도)
	var trap_pos_1 = Vector2i(1, 0)
	var trap_pos_2 = Vector2i(2, 0)
	
	# AStarGrid2D의 가중치 설정 (실제 엔진 버전에 따라 메서드명이 다를 수 있음)
	grid_manager.astar.set_point_weight_scale(trap_pos_1, 100.0)
	grid_manager.astar.set_point_weight_scale(trap_pos_2, 100.0)
	
	# 2. 길찾기 수행
	var path = grid_manager.get_hex_path(player.grid_pos, enemy.grid_pos)
	
	# 3. 검증: 생성된 경로가 (1,0)이나 (2,0)을 포함하지 않아야 합니다. (우회했는지 확인)
	var stepped_on_trap = false
	for p in path:
		if p == trap_pos_1 or p == trap_pos_2:
			stepped_on_trap = true
			break
	
	assert_false(stepped_on_trap, "AI 패스파인딩은 함정 타일(가중치 높음)을 우회해야 합니다.")
	assert_gt(path.size(), 0, "도달할 수 있는 우회 경로가 존재해야 합니다.")

# ----------------------------------------------------------------------
# [Build 3] 강제 이동기 (Knockback) 테스트
# ----------------------------------------------------------------------
func test_knockback_logic():
	# 시나리오: 플레이어가 적을 타격하여 뒤로 밀어냅니다.
	player.grid_pos = Vector2i(1, 1)
	enemy.grid_pos = Vector2i(2, 1)
	
	# 넉백 로직: 공격자에서 피격자를 향하는 방향 벡터 계산
	var direction = enemy.grid_pos - player.grid_pos
	
	# 1칸 밀어냄 (정확한 헥스 방향 계산은 별도 유틸 함수가 필요하나 여기서는 단순 X축 이동으로 가정)
	var push_distance = 1
	var target_pos = enemy.grid_pos + (direction * push_distance)
	
	# 타일 유효성 및 충돌 검사
	var is_valid_push = grid_manager.astar.is_in_bounds(target_pos.x, target_pos.y)
	if is_valid_push and not grid_manager.is_tile_occupied(target_pos):
		# 점유 해제 및 위치 갱신
		grid_manager.clear_tile_occupancy(enemy.grid_pos)
		enemy.grid_pos = target_pos
		grid_manager.set_tile_occupied(enemy.grid_pos, enemy)
	
	assert_eq(enemy.grid_pos, Vector2i(3, 1), "적은 넉백되어 (3, 1) 위치로 밀려나야 합니다.")

# ----------------------------------------------------------------------
# [Build 2 & 3 통합] 함정으로 밀어넣기(Knockback into Trap) 상호작용 테스트
# ----------------------------------------------------------------------
func test_environmental_hazard_on_forced_displacement():
	# 시나리오: 적 바로 뒤 (3,1)에 가시 함정이 있습니다. 플레이어가 적을 그곳으로 넉백시킵니다.
	player.grid_pos = Vector2i(1, 1)
	enemy.grid_pos = Vector2i(2, 1)
	
	var trap_pos = Vector2i(3, 1)
	
	# 가상 시스템: grid_manager 내부에 함정 데이터 등록
	# grid_manager.grid_data[trap_pos] = TileType.TRAP
	# 임시로 이 테스트 안에서 타일 타입을 지정했다고 가정
	var is_trap_tile = true # 나중에 grid_manager.get_tile_type(trap_pos) == TileType.TRAP 로 대체
	
	# 넉백 수행
	var direction = enemy.grid_pos - player.grid_pos
	var target_pos = enemy.grid_pos + direction
	
	enemy.grid_pos = target_pos
	
	# 함정 발동 로직 트리거
	var damage_taken = 0
	if target_pos == trap_pos and is_trap_tile:
		var trap_damage = 15
		enemy.take_damage(trap_damage) # 체력 차감
		damage_taken = trap_damage
		
		# 추가로 상태이상 부여 (예: 출혈)
		# enemy.apply_status_effect("bleed", 2)
	
	assert_eq(damage_taken, 15, "강제 이동으로 함정을 밟은 적은 함정 데미지를 입어야 합니다.")
	assert_eq(enemy.current_stats.health.current_value, 35, "적의 HP가 함정 피해만큼 감소해야 합니다.")

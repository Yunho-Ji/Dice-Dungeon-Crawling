extends Node2D

# 타일 전투 프로토타입 메인 컨트롤러
var grid_manager: HexGridManager
var player_unit: HexUnit
var enemy_unit: HexUnit

@onready var grid_layer: TileMapLayer = $GridLayer
@onready var ui_layer: CanvasLayer = $UI

func _ready():
	grid_manager = $GridManager
	_setup_test_environment()

func _setup_test_environment():
	# 1. 플레이어 유닛 생성
	player_unit = _spawn_unit("Player", Vector2i(7, 8), Color.BLUE)
	
	# 2. 적 유닛 생성
	enemy_unit = _spawn_unit("Enemy", Vector2i(7, 1), Color.RED)
	
	# 3. 타겟 설정 (추격 AP 테스트용)
	player_unit.target_unit = enemy_unit
	
	print("--- 테스트 환경 준비 완료 ---")
	print("플레이어 지능(INT): ", player_unit.int_stat)
	print("현재 상태: 배치 페이즈 (안전 구역 내 클릭하여 위치 이동)")

func _spawn_unit(u_name: String, pos: Vector2i, color: Color) -> HexUnit:
	var unit = preload("res://levels/test/HexUnit.gd").new() # 임시로 스크립트만 생성
	unit.unit_name = u_name
	unit.grid_pos = pos
	unit.grid_manager = grid_manager
	unit.modulate = color
	$Units.add_child(unit)
	unit.position = grid_manager.map_to_local(pos)
	return unit

## UI 이벤트: 그리드 가시성 토글
func _on_grid_toggle_pressed():
	grid_layer.visible = !grid_layer.visible

## UI 이벤트: 전투 시작
func _on_battle_start_pressed():
	print("--- 전투 시작! ---")
	# 본격적인 전투 루프 진입 로직 (추격 및 이동 활성화)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var map_pos = grid_manager.local_to_map(get_local_mouse_position())
			_handle_tile_click(map_pos)

func _handle_tile_click(map_pos: Vector2i):
	# 유닛 스스로 배치가 가능한지 확인하고 이동하도록 위임 (SOLID)
	if player_unit.place_at(map_pos):
		print("플레이어 배치 성공: ", map_pos)
	else:
		print("배치 불가 지역입니다 (안전 구역이 아님): ", map_pos)

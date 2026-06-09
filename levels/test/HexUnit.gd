extends Node2D

# 테스트용 유닛 (추격 AP 로직 포함)
class_name HexUnit

signal ap_changed(new_value: float, is_pursuit: bool)

@export var unit_name: String = "TestUnit"
@export var move_range: int = 3
@export var attack_range: int = 1
@export var spd: float = 20.0 # 초당 AP 충전량
@export var int_stat: int = 15 # 함정 탐지 사거리 결정

var current_ap: float = 0.0
var is_pursuit_mode: bool = false
var target_unit: HexUnit = null

@export var grid_pos: Vector2i:
	set(value):
		grid_pos = value
		if grid_manager:
			position = grid_manager.map_to_local(value)

var grid_manager: HexGridManager

## 유닛을 특정 그리드 좌표에 배치 (배치 페이즈용)
func place_at(new_pos: Vector2i) -> bool:
	if not grid_manager: return false
	
	if grid_manager.is_valid_spawn_zone(new_pos):
		grid_pos = new_pos
		return true
	return false

func _process(delta: float):
	_update_ap(delta)

func _update_ap(delta: float):
	if current_ap >= 100.0:
		return
		
	var multiplier = 1.0
	var was_pursuit = is_pursuit_mode
	
	# 추격 모드 판정
	if target_unit:
		var dist = get_dist_to(target_unit.grid_pos)
		if dist > attack_range:
			is_pursuit_mode = true
			multiplier = 1.5 # 추격 가속 (v7.4 설계)
		else:
			if is_pursuit_mode:
				# 사거리 진입 시 AP 리셋 (v7.4 설계)
				current_ap = 0.0
				is_pursuit_mode = false
	
	current_ap += spd * multiplier * delta
	current_ap = min(current_ap, 100.0)
	
	ap_changed.emit(current_ap, is_pursuit_mode)

func get_dist_to(target_pos: Vector2i) -> int:
	# 육각 그리드 거리 계산 (Axial distance)
	var d_col = target_pos.x - grid_pos.x
	var d_row = target_pos.y - grid_pos.y
	return (abs(d_col) + abs(d_col + d_row) + abs(d_row)) / 2

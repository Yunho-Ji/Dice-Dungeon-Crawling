extends Node2D

class_name HexGridManager

enum TileType { EMPTY, VOID, TRAP, SAFE_ZONE }

@export var grid_width: int = 7
@export var grid_height: int = 5
@export var tile_size: Vector2 = Vector2(80, 80)

var show_grid: bool = true

var grid_data: Dictionary = {}
var occupied_tiles: Dictionary = {} # [신규] 타일 점유 상태 (Vector2i -> Node)
var astar: AStarGrid2D = AStarGrid2D.new()

func _ready():
	_initialize_grid()
	queue_redraw()

func toggle_grid_visibility():
	show_grid = !show_grid
	queue_redraw()
	print("HexGridManager: Grid visibility -> ", show_grid)

func _initialize_grid():
	grid_data.clear()
	occupied_tiles.clear()
	
	astar.region = Rect2i(0, 0, grid_width, grid_height)
	astar.cell_size = tile_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.offset = tile_size / 2
	astar.update()
	
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if x <= 1:
				grid_data[pos] = TileType.SAFE_ZONE
			else:
				grid_data[pos] = TileType.EMPTY

# [신규] 타일 점유 설정 (다른 유닛이 접근 못하도록 AStar를 Solid로 만듦)
func set_tile_occupied(coords: Vector2i, entity: Node):
	occupied_tiles[coords] = entity
	if astar.is_in_bounds(coords.x, coords.y):
		astar.set_point_solid(coords, true)

# [신규] 타일 점유 해제
func clear_tile_occupancy(coords: Vector2i):
	if occupied_tiles.has(coords):
		occupied_tiles.erase(coords)
	if astar.is_in_bounds(coords.x, coords.y) and not is_void(coords):
		astar.set_point_solid(coords, false)

# [신규] 타일 점유 여부 확인
func is_tile_occupied(coords: Vector2i) -> bool:
	if occupied_tiles.has(coords):
		var entity = occupied_tiles[coords]
		if is_instance_valid(entity):
			return true
		else:
			# 파괴된 개체의 잔재 청소
			occupied_tiles.erase(coords)
			if astar.is_in_bounds(coords.x, coords.y) and not is_void(coords):
				astar.set_point_solid(coords, false)
	return false

func _draw():
	if not show_grid: return
	
	for y in range(grid_height):
		for x in range(grid_width):
			var center = map_to_local(Vector2i(x, y))
			var tile_type = get_tile_type(Vector2i(x, y))
			
			var border_color = Color(1.0, 1.0, 1.0, 0.4) # 일반 타일 테두리
			var fill_color = Color(1.0, 1.0, 1.0, 0.0) # 투명
			
			if tile_type == TileType.SAFE_ZONE:
				border_color = Color(0.2, 0.8, 0.2, 1.0) # 세이프존 뚜렷한 초록색 테두리
				fill_color = Color(0.2, 0.8, 0.2, 0.05) # 내부는 거의 투명하게
				
			_draw_hex(center, tile_size.y * 0.5, border_color, fill_color)
			
			# 좌표 텍스트 그리기 (옵션)
			var font = ThemeDB.fallback_font
			if font:
				draw_string(font, center + Vector2(-15, 5), str(x)+","+str(y), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 1, 1, 0.3))

func _draw_hex(center: Vector2, size: float, border_color: Color, fill_color: Color):
	var points = PackedVector2Array()
	# Pointy Top Hexagon: 30, 90, 150, 210, 270, 330 degrees
	for i in range(6):
		var angle_deg = 60 * i - 30
		var angle_rad = deg_to_rad(angle_deg)
		points.append(center + Vector2(cos(angle_rad), sin(angle_rad)) * size)
	points.append(points[0]) # 닫기
	
	# 내부 칠하기
	if fill_color.a > 0.0:
		var fill_colors = PackedColorArray()
		for i in range(7): fill_colors.append(fill_color)
		draw_polygon(points, fill_colors)
		
	# 테두리 그리기
	draw_polyline(points, border_color, 2.0)

func is_void(coords: Vector2i) -> bool:
	return get_tile_type(coords) == TileType.VOID

func get_tile_type(coords: Vector2i) -> int:
	if grid_data.has(coords):
		return grid_data[coords]
	return TileType.VOID

func is_valid_spawn_zone(coords: Vector2i) -> bool:
	return get_tile_type(coords) == TileType.SAFE_ZONE

func map_to_local(coords: Vector2i) -> Vector2:
	# Pointy Top Hexagon math
	var w = tile_size.y * sqrt(3) / 2.0
	var h = tile_size.y * 0.75
	
	var x = coords.x * w + 100 # X 시작 오프셋
	if coords.y % 2 == 1:
		x += w / 2.0 # 지그재그 보정
	var y = coords.y * h + 150 # Y 시작 오프셋
	
	return Vector2(x, y)

func local_to_map(world_pos: Vector2) -> Vector2i:
	var h = tile_size.y * 0.75
	var w = tile_size.y * sqrt(3) / 2.0
	
	var y_rough = roundi((world_pos.y - 150) / h)
	var x_offset = 100.0
	if y_rough % 2 == 1:
		x_offset += w / 2.0
	
	var x_rough = roundi((world_pos.x - x_offset) / w)
	return Vector2i(x_rough, y_rough)

func get_hex_path(start: Vector2i, end: Vector2i, detection_range: int = 0) -> Array[Vector2i]:
	if not astar.is_in_bounds(start.x, start.y) or not astar.is_in_bounds(end.x, end.y):
		return []
		
	# 목적지가 점유되어 있으면 길을 못 찾으므로 임시 개방
	var was_solid = astar.is_point_solid(end)
	if was_solid:
		astar.set_point_solid(end, false)
		
	var path = astar.get_id_path(start, end)
	
	# 목적지 상태 원복
	if was_solid:
		astar.set_point_solid(end, true)
		
	var result: Array[Vector2i] = []
	for p in path:
		result.append(Vector2i(p.x, p.y))
	return result

# InventoryData.gd
# 인벤토리의 데이터 모델 (MVC의 Model)
class_name InventoryData
extends Resource

signal items_changed

@export var size: Vector2i = Vector2i(10, 5)
@export var items: Array[InventoryItem] = []

# 그리드 점유 상태를 나타내는 2D 배열 (캐싱용)
var _grid: Array = []

func _init(p_size: Vector2i = Vector2i(10, 5)):
	size = p_size
	_rebuild_grid()

func _rebuild_grid():
	_grid = []
	for y in range(size.y):
		var row = []
		for x in range(size.x):
			row.append(null)
		_grid.append(row)
	
	for item in items:
		_add_item_to_grid_cache(item)

func _add_item_to_grid_cache(item: InventoryItem):
	var item_size = item.get_size()
	for y in range(item_size.y):
		for x in range(item_size.x):
			var gy = item.grid_position.y + y
			var gx = item.grid_position.x + x
			if gy < size.y and gx < size.x:
				_grid[gy][gx] = item

func can_place_item(item_id: String, pos: Vector2i, rotated: bool = false) -> bool:
	var temp_item = InventoryItem.new()
	temp_item.id = item_id
	temp_item.is_rotated = rotated
	var item_size = temp_item.get_size()
	
	if pos.x < 0 or pos.y < 0 or pos.x + item_size.x > size.x or pos.y + item_size.y > size.y:
		return false
	
	for y in range(item_size.y):
		for x in range(item_size.x):
			if _grid[pos.y + y][pos.x + x] != null:
				return false
	return true

func add_item(item_id: String, pos: Vector2i = Vector2i(-1, -1), rotated: bool = false) -> bool:
	# 위치가 -1, -1이면 빈 공간 자동 찾기
	if pos == Vector2i(-1, -1):
		pos = find_free_space(item_id, rotated)
		if pos == Vector2i(-1, -1):
			return false # 공간 부족
			
	if can_place_item(item_id, pos, rotated):
		var new_item = InventoryItem.new()
		new_item.id = item_id
		new_item.grid_position = pos
		new_item.is_rotated = rotated
		
		items.append(new_item)
		_add_item_to_grid_cache(new_item)
		items_changed.emit()
		return true
	return false

func remove_item(item: InventoryItem):
	if items.has(item):
		items.erase(item)
		_rebuild_grid()
		items_changed.emit()

func find_free_space(item_id: String, rotated: bool = false) -> Vector2i:
	var temp_item = InventoryItem.new()
	temp_item.id = item_id
	temp_item.is_rotated = rotated
	var item_size = temp_item.get_size()
	
	for y in range(size.y - item_size.y + 1):
		for x in range(size.x - item_size.x + 1):
			if can_place_item(item_id, Vector2i(x, y), rotated):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func get_item_at(pos: Vector2i) -> InventoryItem:
	if pos.x >= 0 and pos.x < size.x and pos.y >= 0 and pos.y < size.y:
		return _grid[pos.y][pos.x]
	return null

func to_dict() -> Dictionary:
	var items_data = []
	for item in items:
		items_data.append(item.to_dict())
	return {
		"size": {"x": size.x, "y": size.y},
		"items": items_data
	}

static func from_dict(dict: Dictionary) -> InventoryData:
	var s = dict.get("size", {"x": 10, "y": 5})
	var inv = InventoryData.new(Vector2i(s.x, s.y))
	var items_list = dict.get("items", [])
	for item_dict in items_list:
		var item = InventoryItem.from_dict(item_dict)
		inv.items.append(item)
	inv._rebuild_grid()
	return inv

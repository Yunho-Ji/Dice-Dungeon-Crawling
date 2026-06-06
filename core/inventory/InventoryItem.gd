# InventoryItem.gd
# 인벤토리 내의 개별 아이템 인스턴스 데이터
class_name InventoryItem
extends Resource

@export var id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO
@export var is_rotated: bool = false
@export var current_stack: int = 1
@export var extra_data: Dictionary = {} # 내구도, 강화 수치 등 가변 데이터

func get_data() -> Dictionary:
	var data = DataManager.get_item(id)
	return data

func get_size() -> Vector2i:
	var data = DataManager.get_item(id)
	var pattern_id = data.get("pattern", "1x1")
	var pattern = DataManager.get_item_pattern(pattern_id)
	
	var rows = pattern.size()
	var cols = pattern[0].size()
	
	if is_rotated:
		return Vector2i(rows, cols)
	return Vector2i(cols, rows)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"is_rotated": is_rotated,
		"current_stack": current_stack,
		"extra_data": extra_data
	}

static func from_dict(dict: Dictionary) -> InventoryItem:
	var item = InventoryItem.new()
	item.id = dict.get("id", "")
	var pos = dict.get("grid_position", {"x": 0, "y": 0})
	item.grid_position = Vector2i(pos.x, pos.y)
	item.is_rotated = dict.get("is_rotated", false)
	item.current_stack = dict.get("current_stack", 1)
	item.extra_data = dict.get("extra_data", {})
	return item

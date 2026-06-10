# DataManager.gd
# 역할: 게임 내 정적 데이터(아이템 DB, 몬스터 정보, 스킬 데이터)를 로드하고 제공합니다.
extends Node

const ITEM_DB_PATH := "res://data/item_db.json"
const ITEM_ICONS_PATH := "res://assets/sprites/items/" # 새 아이콘 경로 (필요 시 수정)

var items := {} # 아이템 데이터베이스

const ITEM_PATTERNS = {
	"1x1": [[1]],
	"2x2": [[1, 1], [1, 1]],
	"1x2": [[1], [1]],
	"2x1": [[1, 1]],
	"2x3": [[1, 1], [1, 1], [1, 1]],
	"3x3": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
	"3x1": [[1, 1, 1]],
	"1x3": [[1], [1], [1]],
	"L": [[1, 0], [1, 0], [1, 1]],
	"T": [[1, 1, 1], [0, 1, 0]],
}

func _ready():
	load_item_database()

func load_item_database():
	if FileAccess.file_exists(ITEM_DB_PATH):
		var file = FileAccess.open(ITEM_DB_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var parsed_data = JSON.parse_string(json_string)
		if parsed_data is Dictionary:
			items = parsed_data
			print("DataManager: Item database loaded successfully. (Count: ", items.size(), ")")
		else:
			printerr("DataManager: Failed to parse item_db.json")
	else:
		printerr("DataManager: item_db.json not found at ", ITEM_DB_PATH)

func get_item(id: String) -> Dictionary:
	if items.has(id):
		return items[id].duplicate()
	return {}

func get_item_pattern(pattern_id: String) -> Array:
	return ITEM_PATTERNS.get(pattern_id, ITEM_PATTERNS["1x1"])

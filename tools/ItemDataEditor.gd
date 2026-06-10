extends Control

# 아이템 데이터베이스 경로
const ITEM_DB_PATH = "res://data/item_db.json"

var item_db = {}
var current_selected_id = ""

@onready var item_list = $HBox/Left/ItemList
@onready var detail_container = $HBox/Right/Details
@onready var save_button = $HBox/Right/Footer/SaveButton

# 입력 필드들
@onready var id_edit = $HBox/Right/Details/IDEdit
@onready var name_edit = $HBox/Right/Details/NameEdit
@onready var pattern_option = $HBox/Right/Details/PatternOption
@onready var grade_option = $HBox/Right/Details/GradeOption

func _ready():
	_load_db()
	_setup_ui()
	_refresh_list()

func _load_db():
	if FileAccess.file_exists(ITEM_DB_PATH):
		var file = FileAccess.open(ITEM_DB_PATH, FileAccess.READ)
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary:
			item_db = json
			print("ItemEditor: DB Loaded.")

func _setup_ui():
	# 패턴 옵션 초기화
	pattern_option.clear()
	var patterns = ["1x1", "1x2", "2x1", "2x2", "1x3", "3x1", "2x3", "3x3", "L", "T"]
	for p in patterns:
		pattern_option.add_item(p)
		
	# 등급 옵션 초기화
	grade_option.clear()
	var grades = ["common", "uncommon", "rare", "epic", "legendary", "relic"]
	for g in grades:
		grade_option.add_item(g)

func _refresh_list():
	item_list.clear()
	for id in item_db.keys():
		item_list.add_item(id)

func _on_item_list_item_selected(index):
	current_selected_id = item_list.get_item_text(index)
	var data = item_db[current_selected_id]
	
	id_edit.text = current_selected_id
	name_edit.text = data.get("name", "")
	
	var pattern = data.get("pattern", "1x1")
	for i in range(pattern_option.item_count):
		if pattern_option.get_item_text(i) == pattern:
			pattern_option.selected = i
			break
			
	var grade = data.get("grade", "common")
	for i in range(grade_option.item_count):
		if grade_option.get_item_text(i) == grade:
			grade_option.selected = i
			break

func _on_save_pressed():
	if current_selected_id == "": return
	
	var data = item_db[current_selected_id]
	data["name"] = name_edit.text
	data["pattern"] = pattern_option.get_item_text(pattern_option.selected)
	data["grade"] = grade_option.get_item_text(grade_option.selected)
	
	var file = FileAccess.open(ITEM_DB_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(item_db, "\t"))
	file.close()
	print("ItemEditor: Saved to ", ITEM_DB_PATH)
	_refresh_list()

func _on_add_new_pressed():
	var new_id = "new_item_" + str(Time.get_ticks_msec())
	item_db[new_id] = {
		"name": "새 아이템",
		"pattern": "1x1",
		"grade": "common",
		"equip_type": "none",
		"stats": {}
	}
	_refresh_list()
	# 새로 추가된 아이템 선택
	for i in range(item_list.item_count):
		if item_list.get_item_text(i) == new_id:
			item_list.select(i)
			_on_item_list_item_selected(i)
			break

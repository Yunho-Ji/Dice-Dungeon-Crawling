extends Node

#Signals
signal item_added(to_inv: GridInventory, item: DraggableItem)
signal item_removed(from_inv: GridInventory, item: DraggableItem)
signal item_updated(in_inv: GridInventory, item: DraggableItem)

#Data
enum Rarity {COMMON, UNCOMMON, RARE, EPIC, LEGENDARY}
const ITEM_ICONS_PATH := "res://addons/apeloot/image/examples/"
const ITEM_DB_PATH := "res://data/item_db.json"
const INVENTORY_ITEM_SIZE := Vector2(56,56)

var items := {} # JSON에서 로드됨
var inventory_refs := {}
var drag_layer := CanvasLayer.new()
var temp_node := Control.new()

func _ready():
	# 드래그 아이템을 최상단에 표시하기 위한 전용 레이어 설정
	drag_layer.layer = 128 # InventoryScreen(100)보다 높아야 함
	add_child(drag_layer)
	
	# 실제 아이템이 추가될 컨트롤 노드
	# [수정] CanvasLayer 아래 Control은 앵커가 작동하지 않으므로 크기를 직접 지정하거나
	# 뷰포트 크기에 맞게 설정해야 함. (여기서는 간단히 Full Rect로 설정하되, 동작 확인 필요)
	# 더 확실하게 하기 위해 _process에서 갱신하거나, 단순히 큰 크기를 줌.
	temp_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	# [추가] 앵커가 안 먹힐 경우를 대비해 넉넉한 크기 설정
	temp_node.custom_minimum_size = Vector2(1920, 1080) 
	temp_node.size = Vector2(1920, 1080)
	
	temp_node.mouse_filter = Control.MOUSE_FILTER_IGNORE # 입력 가로채기 방지
	drag_layer.add_child(temp_node)
	
	# 아이템 데이터베이스 로드
	load_items_from_json()

func load_items_from_json():
	if FileAccess.file_exists(ITEM_DB_PATH):
		var file = FileAccess.open(ITEM_DB_PATH, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var parsed_data = JSON.parse_string(json_string)
		if parsed_data is Dictionary:
			items = parsed_data
			print("Apeloot: Item database loaded successfully. (Count: ", items.size(), ")")
		else:
			printerr("Apeloot: Failed to parse item_db.json")
	else:
		printerr("Apeloot: item_db.json not found at ", ITEM_DB_PATH)

const item_patterns = {
	"1x1": [[1]],
	"2x2": [
		[1, 1],
		[1, 1]
	],
	"1x2": [
		[0,1],
		[0,1]
	],
	"2x1": [
		[0,0],
		[1,1],
	],
	"3x3": [
		[1, 1, 1],
		[1, 1, 1],
		[1, 1, 1]
	],
	"3x1": [
		[0, 0, 0],
		[1, 1, 1],
		[0, 0, 0],
	],
	"3x2": [
		[1, 1, 1],
		[1, 1, 1],
	],
	"4x4": [
		[1, 1, 1, 1],
		[1, 1, 1, 1],
		[1, 1, 1, 1],
		[1, 1, 1, 1],
	],
	"T": [
		[1, 1, 1],
		[0, 1, 0],
		[0, 1, 0]
	],
	"diagonal": [
		[0,1],
		[1,0]
	],
	"diagonal3": [
		[0,0,1],
		[0,1,0],
		[1,0,0],
	],
}

const rarities := {
	Rarity.COMMON: {"name": "Common", "color": Color.WHITE, "chance": 0.6},
	Rarity.UNCOMMON: {"name": "Uncommon", "color": Color.GREEN_YELLOW, "chance": 0.25},
	Rarity.RARE: {"name": "Rare", "color": Color.DODGER_BLUE, "chance": 0.1},
	Rarity.EPIC: {"name": "Epic", "color": Color.MEDIUM_PURPLE, "chance": 0.04},
	Rarity.LEGENDARY: {"name": "Legendary", "color": Color.ORANGE_RED, "chance": 0.01},
}

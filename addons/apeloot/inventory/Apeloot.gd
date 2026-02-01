extends Node

#Signals
signal item_added(to_inv: GridInventory, item: DraggableItem)
signal item_removed(from_inv: GridInventory, item: DraggableItem)
signal item_updated(in_inv: GridInventory, item: DraggableItem)

#Startup
var inventory_refs := {}
@onready var drag_layer = CanvasLayer.new()
@onready var temp_node = Control.new()

func _ready():
	# 드래그 아이템을 최상단에 표시하기 위한 전용 레이어 설정
	drag_layer.layer = 128 # InventoryScreen(100)보다 높아야 함
	add_child(drag_layer)
	
	# 실제 아이템이 추가될 컨트롤 노드
	temp_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	temp_node.mouse_filter = Control.MOUSE_FILTER_IGNORE # 입력 가로채기 방지
	drag_layer.add_child(temp_node)

#Data
enum Rarity {COMMON, UNCOMMON, RARE, EPIC, LEGENDARY}
const ITEM_ICONS_PATH := "res://addons/apeloot/image/examples/"
const INVENTORY_ITEM_SIZE := Vector2(56,56)
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

const items := {
	"steak": {
		"name": "Steak",
		"desc": "Made from happy cows.",
		"price": 31,
		"rarity": Rarity.COMMON,
		"pattern": "3x1",
		"merge": true,
	},
	"pickaxe": {
		"name": "Pickaxe",
		"desc": "A test item that was drawn in paint.",
		"price": 50,
		"rarity": Rarity.COMMON,
		"pattern": "T",
		"merge": true,
	},
	"ketchup": {
		"name": "Ketchup",
		"desc": "Goes well with steak.",
		"price": 10,
		"rarity": Rarity.UNCOMMON,
		"stack": 66,
	},
	"glasses": {
		"name": "Glasses?",
		"desc": "I don't know what this is.",
		"price": 31,
		"rarity": Rarity.COMMON,
		"pattern": "diagonal",
		"merge": true,
	},
	"gold_pile_small": {
		"name": "금화 더미",
		"desc": "주머니가 버티지 못하고 터져나왔습니다. 가방 한구석을 차지하기 시작합니다.",
		"price": 0,
		"rarity": Rarity.UNCOMMON,
		"pattern": "2x2",
		"is_gold": true,
		"is_cursed": true,
	},
	"gold_pile_medium": {
		"name": "무너지는 금화 더미",
		"desc": "돈이 기하급수적으로 불어나며 자꾸만 쏟아집니다. 당신은 부자입니까, 아니면 짐꾼입니까?",
		"price": 0,
		"rarity": Rarity.RARE,
		"pattern": "3x3",
		"is_gold": true,
		"is_cursed": true,
	},
	"gold_pile_large": {
		"name": "탐욕의 금화 산",
		"desc": "가방이 비명을 지르고 있습니다. 감당할 수 없는 무게는 저주와 다를 바 없습니다. 무엇인가를 희생해야만 할 것입니다.",
		"price": 0,
		"rarity": Rarity.EPIC,
		"pattern": "4x4",
		"is_gold": true,
		"is_cursed": true,
	},
}

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
		"equip_type": "none"
	},
	"pickaxe": {
		"name": "Pickaxe",
		"desc": "A test item that was drawn in paint.",
		"price": 50,
		"rarity": Rarity.COMMON,
		"pattern": "T",
		"merge": true,
		"equip_type": "weapon"
	},
	"ketchup": {
		"name": "Ketchup",
		"desc": "Goes well with steak.",
		"price": 10,
		"rarity": Rarity.UNCOMMON,
		"stack": 66,
		"equip_type": "none"
	},
	"glasses": {
		"name": "Glasses?",
		"desc": "I don't know what this is.",
		"price": 31,
		"rarity": Rarity.COMMON,
		"pattern": "diagonal",
		"merge": true,
		"equip_type": "accessory"
	},
	"rusty_sword": {
		"name": "녹슨 검",
		"desc": "금방이라도 부러질 것 같은 검입니다. 그래도 맨손보다는 낫습니다.",
		"price": 100,
		"rarity": Rarity.COMMON,
		"pattern": "1x2",
		"equip_type": "weapon",
		"stats": {"atk": 2}
	},
	"wooden_shield": {
		"name": "나무 방패",
		"desc": "가벼운 목재로 만든 방패입니다.",
		"price": 80,
		"rarity": Rarity.COMMON,
		"pattern": "2x2",
		"equip_type": "shield",
		"stats": {"def": 2}
	},
	"leather_top": {
		"name": "가죽 상의",
		"desc": "질긴 가죽으로 만든 기본적인 갑옷입니다.",
		"price": 150,
		"rarity": Rarity.COMMON,
		"pattern": "2x2",
		"equip_type": "top",
		"stats": {"def": 3, "hp": 5}
	},
	"leather_cap": {
		"name": "가죽 모자",
		"desc": "머리를 보호하기 위한 간단한 모자입니다.",
		"price": 80,
		"rarity": Rarity.COMMON,
		"pattern": "1x1",
		"equip_type": "head",
		"stats": {"def": 1}
	},
	"leather_pants": {
		"name": "가죽 바지",
		"desc": "활동성이 좋은 가죽 바지입니다.",
		"price": 120,
		"rarity": Rarity.COMMON,
		"pattern": "2x2",
		"equip_type": "bottom",
		"stats": {"def": 2, "hp": 2}
	},
	"leather_boots": {
		"name": "가죽 장화",
		"desc": "단단한 가죽으로 만든 장화입니다.",
		"price": 90,
		"rarity": Rarity.COMMON,
		"pattern": "1x2",
		"equip_type": "shoes",
		"stats": {"def": 1, "spd": 2}
	},
	"iron_ring": {
		"name": "철 반지",
		"desc": "평범한 철제 반지입니다. 왠지 행운이 따를 것 같습니다.",
		"price": 200,
		"rarity": Rarity.UNCOMMON,
		"pattern": "1x1",
		"equip_type": "accessory",
		"stats": {"luck": 1}
	},
	"gold_pile_small": {
		"name": "금화 더미",
		"desc": "주머니가 버티지 못하고 터져나왔습니다. 가방 한구석을 차지하기 시작합니다.",
		"price": 0,
		"rarity": Rarity.UNCOMMON,
		"pattern": "2x2",
		"is_gold": true,
		"is_cursed": true,
		"equip_type": "none"
	},
	"gold_pile_medium": {
		"name": "무너지는 금화 더미",
		"desc": "돈이 기하급수적으로 불어나며 자꾸만 쏟아집니다. 당신은 부자입니까, 아니면 짐꾼입니까?",
		"price": 0,
		"rarity": Rarity.RARE,
		"pattern": "3x3",
		"is_gold": true,
		"is_cursed": true,
		"equip_type": "none"
	},
	"gold_pile_large": {
		"name": "탐욕의 금화 산",
		"desc": "가방이 비명을 지르고 있습니다. 감당할 수 없는 무게는 저주와 다를 바 없습니다. 무엇인가를 희생해야만 할 것입니다.",
		"price": 0,
		"rarity": Rarity.EPIC,
		"pattern": "4x4",
		"is_gold": true,
		"is_cursed": true,
		"equip_type": "none"
	},
}

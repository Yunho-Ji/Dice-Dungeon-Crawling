# CustomInventoryGrid.gd
# 인벤토리 데이터(Model)를 시각화하고 드래그 앤 드롭을 처리하는 View/Controller
extends Control
class_name CustomInventoryGrid

@export var inventory_data: InventoryData

@onready var grid_container = $GridContainer
@onready var items_container = $ItemsContainer

const SLOT_SCENE = preload("res://ui/inventory/InventorySlotUI.tscn")
const ITEM_UI_SCENE = preload("res://ui/inventory/DraggableItemUI.tscn")
const TILE_SIZE = 40

func _ready():
	if not inventory_data:
		inventory_data = InventoryData.new(Vector2i(10, 5))
	
	inventory_data.items_changed.connect(refresh_ui)
	setup_grid()
	refresh_ui()

func setup_grid():
	# 기존 슬롯 제거
	for child in grid_container.get_children():
		child.queue_free()
	
	grid_container.columns = inventory_data.size.x
	for y in range(inventory_data.size.y):
		for x in range(inventory_data.size.x):
			var slot = SLOT_SCENE.instantiate()
			slot.grid_position = Vector2i(x, y)
			grid_container.add_child(slot)
	
	custom_minimum_size = Vector2(inventory_data.size.x * TILE_SIZE, inventory_data.size.y * TILE_SIZE)

func refresh_ui():
	# 기존 아이템 UI 제거
	for child in items_container.get_children():
		child.queue_free()
	
	# 아이템 데이터 기반으로 UI 생성
	for item in inventory_data.items:
		var item_ui = ITEM_UI_SCENE.instantiate()
		items_container.add_child(item_ui)
		item_ui.setup(item)
		item_ui.position = Vector2(item.grid_position.x * TILE_SIZE, item.grid_position.y * TILE_SIZE)

func _can_drop_data(at_position, data):
	if data is Dictionary and data.has("item"):
		var item = data["item"] as InventoryItem
		var grid_pos = Vector2i(at_position / TILE_SIZE)
		
		# 드래그 중인 마우스 위치 보정 (아이템 중앙 기준 등 필요 시)
		# 현재는 단순하게 마우스 위치가 가리키는 슬롯을 좌상단으로 간주
		return inventory_data.can_place_item(item.id, grid_pos, item.is_rotated)
	return false

func _drop_data(at_position, data):
	var item = data["item"] as InventoryItem
	var grid_pos = Vector2i(at_position / TILE_SIZE)
	
	# 기존 위치에서 제거
	# (동일 인벤토리 내 이동인 경우)
	if data.get("source_node") and data["source_node"].get_parent() == items_container:
		inventory_data.remove_item(item)
	
	# 새 위치에 추가
	inventory_data.add_item(item.id, grid_pos, item.is_rotated)

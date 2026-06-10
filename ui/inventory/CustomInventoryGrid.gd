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
		
		# 자기 자신을 제외하고 해당 위치에 놓을 수 있는지 확인
		return inventory_data.can_place_item_at(item.id, grid_pos, item.is_rotated, item)
	return false

func _drop_data(at_position, data):
	var item = data["item"] as InventoryItem
	var grid_pos = Vector2i(at_position / TILE_SIZE)
	
	# 트랜잭션: 기존 위치에서 제거
	if data.get("source_node"):
		var source = data["source_node"]
		if source.get_parent().name == "ItemsContainer": # 가방 내 이동
			inventory_data.remove_item(item)
		elif source.get_parent() is CustomEquipmentSlotUI: # 장비창에서 가방으로 (해제)
			var old_slot = source.get_parent() as CustomEquipmentSlotUI
			# unequip_item 내부에서 InventoryManager.try_add_item을 호출하여
			# 가방에 넣으려 시도하므로, 여기서는 unequip만 호출하고
			# inventory_data.add_item은 별도로 하지 않거나 (중복 방지)
			# 혹은 unequip의 기본 동작을 가방에 넣지 않도록 하고 여기서 넣어야 함.
			# 현재 PlayerManager.unequip_item은 try_add_item을 호출하므로, 
			# 특정 위치(grid_pos)에 넣기 위해 로직 수정이 필요할 수 있음.
			PlayerManager.unequip_item(old_slot.slot_key)
			# unequip 후 자동 수납된 아이템의 위치를 grid_pos로 강제 조정 (필요 시)
			return # unequip_item에서 이미 처리함

	# 새 위치 및 회전 상태 적용하여 다시 추가
	if not inventory_data.add_item(item.id, grid_pos, item.is_rotated):
		printerr("CustomInventoryGrid: Drop failed at ", grid_pos)

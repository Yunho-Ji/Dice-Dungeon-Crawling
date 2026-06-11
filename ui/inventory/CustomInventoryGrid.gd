# CustomInventoryGrid.gd
# 인벤토리 데이터(Model)를 시각화하고 드래그 앤 드롭을 처리하는 View/Controller
extends Control
class_name CustomInventoryGrid

@export var inventory_data: InventoryData:
	set(value):
		if inventory_data and inventory_data.items_changed.is_connected(refresh_ui):
			inventory_data.items_changed.disconnect(refresh_ui)
		inventory_data = value
		if inventory_data and not inventory_data.items_changed.is_connected(refresh_ui):
			inventory_data.items_changed.connect(refresh_ui)
		if is_node_ready():
			setup_grid()
			refresh_ui()

@export var is_shop: bool = false

@onready var grid_container = $GridContainer
@onready var items_container = $ItemsContainer

const SLOT_SCENE = preload("res://ui/inventory/InventorySlotUI.tscn")
const ITEM_UI_SCENE = preload("res://ui/inventory/DraggableItemUI.tscn")
const TILE_SIZE = 40

func _ready():
	if not inventory_data:
		inventory_data = InventoryData.new(Vector2i(10, 5)) # setter automatically handles connections
	elif not inventory_data.items_changed.is_connected(refresh_ui):
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
		
		# 상점 내부 이동(정렬) 방지
		if is_shop and data.get("source_node"):
			var source = data["source_node"]
			if source.get_parent().name == "ItemsContainer":
				var source_grid = source.get_parent().get_parent() as CustomInventoryGrid
				if source_grid == self:
					return false
		
		# 자기 자신을 제외하고 해당 위치에 놓을 수 있는지 확인
		return inventory_data.can_place_item_at(item.id, grid_pos, item.is_rotated, item)
	return false

func _drop_data(at_position, data):
	var item = data["item"] as InventoryItem
	var grid_pos = Vector2i(at_position / TILE_SIZE)
	
	var is_buy_action = false
	var is_sell_action = false
	var source_grid = null
	var source = null
	
	if data.get("source_node"):
		source = data["source_node"]
		if source.get_parent().name == "ItemsContainer":
			source_grid = source.get_parent().get_parent() as CustomInventoryGrid

	# 상점 관련 로직 판별
	if source_grid != null and source_grid != self:
		if source_grid.is_shop and not self.is_shop:
			is_buy_action = true
		elif not source_grid.is_shop and self.is_shop:
			is_sell_action = true

	var em = get_node_or_null("/root/EconomyManager")
	var item_data = item.get_data()
	var base_price = item_data.get("price", 10)
	
	if is_buy_action:
		var buy_price = base_price
		if em and not em.has_gold(buy_price):
			print("골드가 부족합니다!")
			return # 드롭 취소
		if em:
			em.spend_gold(buy_price)
			
	elif is_sell_action:
		var sell_price = max(1, int(base_price * 0.5))
		if em:
			em.add_gold(sell_price)
	
	# 트랜잭션: 기존 위치에서 제거
	if source:
		if source.get_parent().name == "ItemsContainer": # 가방/상점 내 이동
			if source_grid == self:
				# 내부 이동: move_item 호출하여 인스턴스 유지
				if not inventory_data.move_item(item, grid_pos, item.is_rotated):
					printerr("CustomInventoryGrid: Internal move failed at ", grid_pos)
				return
			else:
				# 다른 그리드에서 온 경우
				source_grid.inventory_data.remove_item(item)
		elif source.get_parent() is CustomEquipmentSlotUI: # 장비창에서 가방으로
			var old_slot = source.get_parent() as CustomEquipmentSlotUI
			PlayerManager.unequip_item_without_add(old_slot.slot_key)

	# 새 위치 및 회전 상태 적용하여 다시 추가
	# 외부에서 온 아이템이므로 새 인스턴스로 추가됨
	if not inventory_data.add_item(item.id, grid_pos, item.is_rotated):
		printerr("CustomInventoryGrid: Drop failed at ", grid_pos)
		# 실패 시 롤백 (단순화: 돈은 환불하지 않고 아이템만 삭제되므로 복잡한 롤백은 추가 구현 필요)
		if is_buy_action and em: em.add_gold(base_price)
		elif is_sell_action and em: em.spend_gold(max(1, int(base_price * 0.5)))
		if source_grid: source_grid.inventory_data.add_item(item.id, item.grid_position, item.is_rotated)

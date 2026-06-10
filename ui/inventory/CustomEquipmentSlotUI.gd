# CustomEquipmentSlotUI.gd
# 특정 부위의 아이템만 장착 가능한 장비 슬롯 UI
extends InventorySlotUI
class_name CustomEquipmentSlotUI

@export var slot_key: String = "" # head, top, bottom, etc.
@export var slot_size: Vector2i = Vector2i(1, 1) # [신규] 슬롯의 고정 그리드 크기 (예: 갑옷 2x2)
@export var allowed_types: Array = []

var occupying_item_ui: DraggableItemUI = null
const TILE_SIZE = 40

func _ready():
	# 슬롯 자체의 크기를 고정 (디아블로 스타일)
	custom_minimum_size = Vector2(slot_size.x * TILE_SIZE, slot_size.y * TILE_SIZE)
	SignalBus.equipment_changed.connect(_on_equipment_changed)
	refresh_visual()

func refresh_visual():
	# 기존 아이템 UI 제거
	for child in get_children():
		if child is DraggableItemUI:
			child.queue_free()
	
	var item_data = PlayerManager.equipment.get(slot_key)
	if item_data:
		var inv_item = InventoryItem.new()
		inv_item.id = item_data.get("id", "")
		# 장착 데이터에 저장된 회전 상태 반영 (필요 시)
		
		var item_ui = preload("res://ui/inventory/DraggableItemUI.tscn").instantiate()
		add_child(item_ui)
		item_ui.setup(inv_item)
		
		# [수정] 슬롯 중앙 정렬 로직
		var item_px_size = item_ui.custom_minimum_size
		item_ui.position = (custom_minimum_size - item_px_size) / 2

func _on_equipment_changed(changed_slot, _item_data):
	if changed_slot == slot_key:
		refresh_visual()

func _can_drop_data(_at_position, data):
	if data is Dictionary and data.has("item"):
		var inv_item = data["item"] as InventoryItem
		var item_def = DataManager.get_item(inv_item.id)
		# item_def에 ID가 없을 수 있으므로 보정
		if not item_def.has("id"): item_def["id"] = inv_item.id
		
		var equip_type = item_def.get("equip_type", "none")
		
		# 타입 체크
		if equip_type in allowed_types:
			return PlayerManager.can_equip_item(item_def)
	return false

func _drop_data(_at_position, data):
	var inv_item = data["item"] as InventoryItem
	var item_def = DataManager.get_item(inv_item.id)
	if not item_def.has("id"): item_def["id"] = inv_item.id
	
	# 1. 기존 위치에서 제거
	if data.get("source_node"):
		var source = data["source_node"]
		if source.get_parent().name == "ItemsContainer": # 가방에서 온 경우
			PlayerManager.inventory_data.remove_item(inv_item)
		elif source.get_parent() is CustomEquipmentSlotUI: # 다른 장비 슬롯에서 온 경우 (위치 교환 등)
			var old_slot = source.get_parent() as CustomEquipmentSlotUI
			PlayerManager.unequip_item(old_slot.slot_key)
	
	# 2. 장착 실행 (SignalBus를 통해 UI 자동 갱신)
	PlayerManager.equip_item(slot_key, item_def)

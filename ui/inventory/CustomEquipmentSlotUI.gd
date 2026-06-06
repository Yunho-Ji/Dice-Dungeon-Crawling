# CustomEquipmentSlotUI.gd
# 특정 부위의 아이템만 장착 가능한 장비 슬롯 UI
extends InventorySlotUI
class_name CustomEquipmentSlotUI

@export var slot_key: String = "" # head, top, bottom, etc.
@export var allowed_types: Array = [] # [수정] 타입 힌트 제거로 유연한 할당 허용

var occupying_item_ui: DraggableItemUI = null

func _can_drop_data(_at_position, data):
	if data is Dictionary and data.has("item"):
		var inv_item = data["item"] as InventoryItem
		var item_def = DataManager.get_item(inv_item.id)
		var equip_type = item_def.get("equip_type", "none")
		
		# 타입 체크
		if equip_type in allowed_types:
			return PlayerManager.can_equip_item(item_def)
	return false

func _drop_data(_at_position, data):
	var inv_item = data["item"] as InventoryItem
	
	# 기존 위치에서 제거 (가방 또는 다른 장비창)
	if data.get("source_node"):
		var source = data["source_node"]
		if source.get_parent().name == "ItemsContainer": # 가방에서 온 경우
			PlayerManager.inventory_data.remove_item(inv_item)
		elif source.get_parent() is CustomEquipmentSlotUI: # 다른 장비 슬롯에서 온 경우
			var old_slot = source.get_parent() as CustomEquipmentSlotUI
			PlayerManager.unequip_item(old_slot.slot_key)
	
	# 장착 실행
	var item_def = DataManager.get_item(inv_item.id)
	PlayerManager.equip_item(slot_key, item_def)
	
	# UI 갱신은 InventoryScreen에서 통합 관리하거나 여기서 직접 처리
	get_parent().get_parent().get_parent().get_parent().get_parent()._refresh_equipment_visuals() # 좀 지저분하지만..

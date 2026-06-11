extends Button

# TrashBin.gd
# 역할: 아이템을 드래그 앤 드롭으로 삭제하는 전용 영역입니다.

func _can_drop_data(_at_position, data):
	return data is Dictionary and "item" in data

func _drop_data(_at_position, data):
	var item = data["item"]
	var source = data.get("source_node")

	if item and is_instance_valid(item):
		print("TrashBin: 아이템 삭제 - ", item.id)

		# 아이템 제거: 소스가 그리드 안에 있으면 inventory_data에서 제거
		if source:
			if source.get_parent().name == "ItemsContainer":
				var source_grid = source.get_parent().get_parent() as CustomInventoryGrid
				if source_grid and source_grid.inventory_data:
					source_grid.inventory_data.remove_item(item)
			elif source.get_parent() is CustomEquipmentSlotUI:
				var old_slot = source.get_parent() as CustomEquipmentSlotUI
				PlayerManager.unequip_item_without_add(old_slot.slot_key)
				item.queue_free()
		else:
			item.queue_free()

		# 시각적 피드백 (버튼 깜빡임 등 가능)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)

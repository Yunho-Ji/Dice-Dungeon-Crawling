extends Button

# TrashBin.gd
# 역할: 아이템을 드래그 앤 드롭으로 삭제하는 전용 영역입니다.

func _can_drop_data(_at_position, data):
	return data is Dictionary and "item" in data

func _drop_data(_at_position, data):
	var item = data["item"]
	if item and is_instance_valid(item):
		print("TrashBin: 아이템 삭제 - ", item.id)
		if item.parent_inventory:
			item.parent_inventory.remove_item(item)
		else:
			item.queue_free()
		
		# 시각적 피드백 (버튼 깜빡임 등 가능)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)

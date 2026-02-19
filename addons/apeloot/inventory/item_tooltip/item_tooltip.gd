extends PanelContainer
class_name ItemTooltip

var item_ref: DraggableItem:
	set(val):
		item_ref = val
		update_props(val)

func update_props(item: DraggableItem):
	if not item: return
	var item_data = Apeloot.items.get(item.id, {})
	if item_data.is_empty(): return
	
	var rarity_data = Apeloot.rarities.get(item.rarity, {"color": Color.WHITE})
	self_modulate = rarity_data["color"]
	
	if has_node("%NameLabel"):
		get_node("%NameLabel").text = item_data.get("name", "Unknown")
		get_node("%NameLabel").modulate = rarity_data["color"]
	
	if has_node("%DescLabel"):
		get_node("%DescLabel").text = item_data.get("desc", "")
	
	# [수정] 스탯 표시 로직 개선
	# VBoxContainer를 찾아 그 아래에 스탯 라벨을 추가합니다.
	var vbox = get_node("MarginContainer/VBoxContainer")
	if vbox:
		# 기존에 동적으로 추가된 스탯 라벨이 있다면 제거 (재사용 시 중복 방지)
		for child in vbox.get_children():
			if child.name.begins_with("StatLabel_"):
				child.queue_free()
		
		# 아이템의 현재 스탯(item.stats) 표시
		var stats = item.stats if not item.stats.is_empty() else item_data.get("stats", {})
		for stat_key in stats.keys():
			var val = stats[stat_key]
			var label = Label.new()
			label.name = "StatLabel_" + stat_key
			
			# StatManager를 통해 정규화된 이름 가져오기 (가능할 경우)
			var display_name = stat_key.to_upper()
			
			if val is Array: # [min, max] 범위형일 경우
				label.text = "%s: %s ~ %s" % [display_name, str(val[0]), str(val[1])]
			else: # 단일 수치일 경우
				label.text = "%s: +%s" % [display_name, str(val)]
			
			label.add_theme_font_size_override("font_size", 12)
			label.modulate = Color(0.8, 0.9, 1.0) # 하늘색 톤
			vbox.add_child(label)
	
	if has_node("%CountLabel"):
		var count_label = get_node("%CountLabel")
		count_label.text = "x" + str(item.stack_count) if item.stack_count > 1 else ""
		count_label.visible = item.stack_count > 1

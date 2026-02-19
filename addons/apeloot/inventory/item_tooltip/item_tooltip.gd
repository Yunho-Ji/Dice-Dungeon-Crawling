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
	
	# [리팩토링] 스탯 표시 로직 개선 (StatInterpreter 위임)
	# VBoxContainer를 찾아 그 아래에 스탯 라벨을 추가합니다.
	var vbox = get_node("MarginContainer/VBoxContainer")
	if vbox:
		# 기존에 동적으로 추가된 스탯 라벨이 있다면 제거 (재사용 시 중복 방지)
		for child in vbox.get_children():
			if child.name.begins_with("StatLabel_"):
				child.queue_free()
		
		# 아이템의 현재 스탯(item.stats) 표시
		var stats_data = item.stats if not item.stats.is_empty() else item_data.get("stats", {})
		
		# StatInterpreter를 통해 효과 객체 리스트로 변환
		var effects = StatInterpreter.parse_stats(stats_data)
		
		for i in range(effects.size()):
			var effect = effects[i]
			var label = Label.new()
			label.name = "StatLabel_" + str(i)
			
			# Effect 객체가 제공하는 설명 사용 (SSOT)
			label.text = effect.get_description()
			
			label.add_theme_font_size_override("font_size", 12)
			label.modulate = Color(0.8, 0.9, 1.0) # 하늘색 톤
			vbox.add_child(label)
	
	if has_node("%CountLabel"):
		var count_label = get_node("%CountLabel")
		count_label.text = "x" + str(item.stack_count) if item.stack_count > 1 else ""
		count_label.visible = item.stack_count > 1

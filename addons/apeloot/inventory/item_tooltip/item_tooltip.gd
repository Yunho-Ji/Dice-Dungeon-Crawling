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
		
	if has_node("%CountLabel"):
		var count_label = get_node("%CountLabel")
		count_label.text = "x" + str(item.stack_count) if item.stack_count > 1 else ""
		count_label.visible = item.stack_count > 1

extends PanelContainer
class_name LootItemSlot

signal take_requested(item_id: String, item_data: Dictionary)

@onready var vbox = $VBoxContainer
@onready var name_label = $VBoxContainer/NameLabel
@onready var rarity_label = $VBoxContainer/RarityLabel
@onready var stats_label = $VBoxContainer/StatsLabel
@onready var take_button = $VBoxContainer/TakeButton

var item_id: String = ""
var item_data: Dictionary = {}

func setup(p_id: String, p_data: Dictionary):
	item_id = p_id
	item_data = p_data
	
	var item_def = Apeloot.items.get(item_id, {})
	var item_name = item_def.get("name", item_id)
	var rarity_str = item_def.get("grade", "common")
	
	# 등급 색상
	var rarity_idx = Apeloot.Rarity.COMMON
	match rarity_str:
		"common": rarity_idx = Apeloot.Rarity.COMMON
		"uncommon": rarity_idx = Apeloot.Rarity.UNCOMMON
		"rare": rarity_idx = Apeloot.Rarity.RARE
		"epic": rarity_idx = Apeloot.Rarity.EPIC
		"relic": rarity_idx = Apeloot.Rarity.LEGENDARY
	var rarity_color = Apeloot.rarities[rarity_idx]["color"]
	
	# 스타일 설정
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	add_theme_stylebox_override("panel", style)
	
	# 라벨 설정
	name_label.text = item_name
	name_label.modulate = rarity_color
	
	rarity_label.text = rarity_str.to_upper()
	rarity_label.modulate = Color(0.7, 0.7, 0.7)
	
	# 스탯 요약
	var stats = item_def.get("stats", {})
	if not stats.is_empty():
		var first_key = stats.keys()[0]
		var val = stats[first_key]
		var val_str = str(val)
		if val is Array: val_str = "%s~%s" % [val[0], val[1]]
		stats_label.text = "%s: %s" % [first_key.to_upper(), val_str]
	else:
		stats_label.text = ""

func _on_take_button_pressed():
	emit_signal("take_requested", item_id, item_data)

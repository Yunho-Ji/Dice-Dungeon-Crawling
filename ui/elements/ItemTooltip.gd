extends PanelContainer
class_name ItemTooltip

var name_label: Label
var type_label: Label
var grade_label: Label
var desc_label: Label
var stats_vbox: VBoxContainer

func _ready():
	# 툴팁 스타일 설정
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.35, 0.2, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	
	custom_minimum_size = Vector2(240, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	add_child(main_vbox)
	
	# 이름 (강조)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(name_label)
	
	var line = ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.4, 0.35, 0.2, 0.5)
	main_vbox.add_child(line)
	
	# 유형 및 등급
	var sub_hbox = HBoxContainer.new()
	main_vbox.add_child(sub_hbox)
	
	type_label = Label.new()
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.modulate = Color(0.7, 0.7, 0.7)
	sub_hbox.add_child(type_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_hbox.add_child(spacer)
	
	grade_label = Label.new()
	grade_label.add_theme_font_size_override("font_size", 14)
	sub_hbox.add_child(grade_label)
	
	# 스탯 보너스 구역
	stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 2)
	main_vbox.add_child(stats_vbox)
	
	# 설명
	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.modulate = Color(0.9, 0.9, 0.8)
	main_vbox.add_child(desc_label)

func setup(item: InventoryItem):
	var data = item.get_data()
	name_label.text = data.get("name", item.id)
	type_label.text = "[" + _get_type_name(data.get("type", "unknown")) + "]"
	
	var grade = data.get("grade", "common")
	grade_label.text = _get_grade_name(grade)
	grade_label.modulate = _get_grade_color(grade)
	name_label.modulate = _get_grade_color(grade)
	
	desc_label.text = data.get("description", "")
	
	# 스탯 표시
	for child in stats_vbox.get_children(): child.queue_free()
	
	if data.has("stats"):
		var stats = data.get("stats")
		for stat_key in stats:
			var val = stats[stat_key]
			var stat_label = Label.new()
			stat_label.text = "%s +%d" % [_get_stat_name(stat_key), val]
			stat_label.add_theme_font_size_override("font_size", 14)
			stat_label.modulate = Color(0.6, 1.0, 0.6)
			stats_vbox.add_child(stat_label)

func _get_type_name(type: String) -> String:
	match type:
		"weapon": return "무기"
		"shield": return "방패"
		"head": return "투구"
		"top": return "상의"
		"bottom": return "하의"
		"shoes": return "신발"
		"accessory": return "장신구"
		"consumable": return "소모품"
	return "아이템"

func _get_grade_name(grade: String) -> String:
	match grade.to_lower():
		"common": return "일반"
		"uncommon": return "고급"
		"rare": return "희귀"
		"epic": return "서사"
		"legendary", "relic": return "전설"
	return "일반"

func _get_grade_color(grade: String) -> Color:
	match grade.to_lower():
		"uncommon": return Color(0.2, 1.0, 0.2)
		"rare": return Color(0.2, 0.6, 1.0)
		"epic": return Color(0.7, 0.2, 1.0)
		"legendary", "relic": return Color(1.0, 0.8, 0.2)
	return Color.WHITE

func _get_stat_name(key: String) -> String:
	match key:
		"atk": return "공격력"
		"vit": return "건강"
		"agi": return "민첩"
		"int_stat": return "지능"
		"spd": return "속도"
		"res": return "저항"
		"spi": return "정신"
		"rec": return "회복력"
	return key

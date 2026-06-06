# DraggableItemUI.gd
# 드래그 앤 드롭이 가능한 인벤토리 아이템 UI
extends Control
class_name DraggableItemUI

var inventory_item: InventoryItem
var tile_size: Vector2 = Vector2(40, 40)

@onready var texture_rect = $TextureRect
@onready var stack_label = $StackLabel

func setup(item: InventoryItem):
	inventory_item = item
	var data = item.get_data()
	var item_size = item.get_size()
	
	custom_minimum_size = Vector2(item_size.x * tile_size.x, item_size.y * tile_size.y)
	size = custom_minimum_size
	
	# 등급 색상 가져오기 (Enums 활용)
	var rarity_str = data.get("grade", "common")
	var rarity_idx = Enums.Rarity.COMMON
	match rarity_str.to_lower():
		"uncommon": rarity_idx = Enums.Rarity.UNCOMMON
		"rare": rarity_idx = Enums.Rarity.RARE
		"epic": rarity_idx = Enums.Rarity.EPIC
		"legendary", "relic": rarity_idx = Enums.Rarity.LEGENDARY
	
	var rarity_color = Enums.RARITY_COLORS.get(rarity_idx, Color.WHITE)
	
	# 텍스처 로드 및 플레이스홀더 처리
	var icon_path = DataManager.ITEM_ICONS_PATH + item.id + ".png"
	var loaded_tex = null
	
	if FileAccess.file_exists(icon_path):
		loaded_tex = load(icon_path)
	
	if loaded_tex:
		texture_rect.texture = loaded_tex
		texture_rect.modulate = Color.WHITE
	else:
		# 아이콘이 없는 경우: 등급 색상의 사각형으로 표시 (플레이스홀더)
		var placeholder_tex = GradientTexture2D.new()
		placeholder_tex.width = 32
		placeholder_tex.height = 32
		var grad = Gradient.new()
		grad.set_color(0, rarity_color.darkened(0.3))
		grad.set_color(1, rarity_color)
		placeholder_tex.gradient = grad
		placeholder_tex.fill = GradientTexture2D.FILL_RADIAL
		placeholder_tex.fill_from = Vector2(0.5, 0.5)
		
		texture_rect.texture = placeholder_tex
		print("DEBUG: DraggableItemUI: Icon not found for '", item.id, "'. Using placeholder.")
	
	if item.current_stack > 1:
		stack_label.text = str(item.current_stack)
		stack_label.visible = true
	else:
		stack_label.visible = false

func _get_drag_data(_at_position):
	var preview = Control.new()
	var preview_texture = texture_rect.duplicate()
	preview_texture.position = -size / 2 # 마우스 중앙 정렬
	preview.add_child(preview_texture)
	set_drag_preview(preview)
	
	# 드래그 중인 아이템의 시각 효과 (반투명)
	modulate.a = 0.5
	
	return { "item": inventory_item, "source_node": self }

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0

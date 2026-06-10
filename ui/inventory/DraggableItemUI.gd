# DraggableItemUI.gd
# 드래그 앤 드롭이 가능한 인벤토리 아이템 UI
extends Control
class_name DraggableItemUI

var inventory_item: InventoryItem
var tile_size: Vector2 = Vector2(40, 40)

@onready var texture_rect = $TextureRect
@onready var stack_label = $StackLabel

var is_hovering: bool = false

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 회전 시 중심점 보정을 위해 pivot_offset 설정
	texture_rect.pivot_offset = Vector2.ZERO 

func setup(item: InventoryItem):
	inventory_item = item
	var data = item.get_data()
	var item_size = item.get_size()
	
	custom_minimum_size = Vector2(item_size.x * tile_size.x, item_size.y * tile_size.y)
	size = custom_minimum_size
	
	# 회전 반영 (UI 갱신 시)
	if item.is_rotated:
		texture_rect.rotation = PI/2
		texture_rect.position = Vector2(custom_minimum_size.x, 0)
	else:
		texture_rect.rotation = 0
		texture_rect.position = Vector2.ZERO
	
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
	
	if item.current_stack > 1:
		stack_label.text = str(item.current_stack)
		stack_label.visible = true
	else:
		stack_label.visible = false

var preview_rect: TextureRect

func _get_drag_data(_at_position):
	InventoryManager.start_drag(inventory_item, self)
	
	var data = { "item": inventory_item, "source_node": self }
	
	# 드래그용 프리뷰 생성
	var preview = Control.new()
	preview_rect = texture_rect.duplicate()
	
	_update_preview_rotation()
	
	preview_rect.modulate.a = 0.7
	preview.add_child(preview_rect)
	
	set_drag_preview(preview)
	
	# 원본 아이템 반투명 처리
	modulate.a = 0.3
	return data

func _update_preview_rotation():
	if not preview_rect: return
	
	var item_size = inventory_item.get_size()
	if inventory_item.is_rotated:
		preview_rect.rotation = PI/2
		# 회전 시 앵커 포인트 보정
		preview_rect.position = Vector2(item_size.x * tile_size.x, 0)
	else:
		preview_rect.rotation = 0
		preview_rect.position = Vector2.ZERO

func _on_mouse_entered():
	is_hovering = true
	# 호버 시 시각적 효과 (예: 테두리 강조 등 추가 가능)

func _on_mouse_exited():
	is_hovering = false

func _input(event):
	# 1. 드래그 중인 경우 회전 처리
	if InventoryManager.dragging_item == inventory_item:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			InventoryManager.rotate_dragging_item()
			_update_preview_rotation()
			get_viewport().set_input_as_handled()
			return

	# 2. 마우스 오버(Hover) 중인 경우 회전 처리
	if is_hovering and not InventoryManager.dragging_item:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			if InventoryManager.try_rotate_item_in_inventory(inventory_item):
				# 성공 시 InventoryData의 items_changed 신호로 인해 UI가 전체 갱신됨
				get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		InventoryManager.end_drag()
		modulate.a = 1.0

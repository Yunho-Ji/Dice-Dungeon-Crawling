extends TextureRect
class_name DraggableTexture

signal dragStarted()

var drag_preview: Control = null
var cursor_visual: TextureRect = null
var full_size: Vector2
var original_position: Vector2
var is_hovering = false
var is_dragging = false:
	set(val):
		is_dragging = val
		visible = not val
		$"../StackLabel".visible = not val

@onready var item_node : DraggableItem = get_parent()

func _ready():
	# 호버링 감지를 위한 시그널 연결
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _get_drag_data(_at_position: Vector2) -> Variant:
	return drag_item()
	
func create_drag_preview():
	# 1. 그리드 가이드 (Snap Guide) 생성
	var preview_scene := preload("res://addons/apeloot/inventory/item_draggable/drag_preview.tscn")
	drag_preview = preview_scene.instantiate()
	
	var guide_texture = drag_preview.texture
	guide_texture.custom_minimum_size = full_size
	guide_texture.pivot_offset = full_size / 2 # 중심점 고정
	guide_texture.rotation = rotation
	guide_texture.z_index = 0
	
	drag_preview.custom_minimum_size = full_size
	drag_preview.item_pattern = Apeloot.item_patterns[Apeloot.items[item_node.id]["pattern"]] if "pattern" in Apeloot.items[item_node.id] else Apeloot.item_patterns["1x1"]
	Apeloot.temp_node.add_child(drag_preview)

	# 2. 커서 비주얼 (Cursor Visual) 생성
	cursor_visual = TextureRect.new()
	cursor_visual.texture = texture
	cursor_visual.expand_mode = expand_mode
	cursor_visual.stretch_mode = stretch_mode
	cursor_visual.custom_minimum_size = full_size
	cursor_visual.size = full_size # [중요] 실제 크기 강제 동기화
	cursor_visual.pivot_offset = full_size / 2 # 중심점 고정
	cursor_visual.rotation = rotation
	cursor_visual.z_index = 100
	cursor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_visual.modulate = Color(1, 1, 1, 0.8)
	Apeloot.temp_node.add_child(cursor_visual)

	update_drag_preview_position()

func update_drag_preview_position():
	var mouse_position = get_global_mouse_position()
	
	# 커서 비주얼 정중앙 배치 (피벗 오프셋 고려)
	if cursor_visual and is_instance_valid(cursor_visual):
		cursor_visual.global_position = mouse_position - (full_size / 2)

	if not (drag_preview and is_instance_valid(drag_preview)):
		return

	var inventory = find_inventory_at_position(mouse_position)
	
	if not inventory or inventory.pickup_only:
		# 인벤토리 밖에서는 마우스 중앙을 따라다니며 프리뷰 유지
		drag_preview.visible = true
		drag_preview.position = mouse_position - (full_size / 2)
		drag_preview.set_collision_state(true)
		return
		
	var center_slot = inventory.find_slot_at_position(mouse_position)
	if center_slot == -1:
		drag_preview.visible = false
		return
	
	drag_preview.visible = true
	drag_preview.single_slot_mode = inventory.single_slot
	var snap_position = inventory.calculate_item_position(item_node, center_slot)
	drag_preview.position = snap_position
	var can_place = inventory.can_place_item(item_node, center_slot)
	drag_preview.set_collision_state(can_place)

func _process(_delta):
	if is_dragging:
		update_drag_preview_position()

func _input(event: InputEvent) -> void:
	if is_dragging:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drop_item()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
			rotate_item()
	elif is_hovering:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			rotate_item_in_place()

func _on_mouse_entered():
	is_hovering = true

func _on_mouse_exited():
	is_hovering = false

func drag_item() -> Variant:
	is_dragging = true
	item_node.original_orientation = item_node.orientation
	original_position = item_node.position
	create_drag_preview()
	var data = {"item": item_node, "original_inventory": item_node.parent_inventory}
	if item_node.parent_inventory:
		item_node.parent_inventory.deregister_item(item_node)
	set_process(true)
	dragStarted.emit()
	return data

func drop_item():
	is_dragging = false
	# Force drop if it wasn't triggered automatically
	var drop_position = get_global_mouse_position()
	var inventory = find_inventory_at_position(drop_position)
	if inventory and not inventory.pickup_only:
		var slot_id = inventory.find_slot_at_position(drop_position)
		var slot = inventory.get_slot_by_index(slot_id)
		if slot:
			slot._drop_data(drop_position, {"item": item_node})
	else:
		var parent_inventory = item_node.parent_inventory
		var center_slot = parent_inventory.find_slot_at_position(drop_position)
		parent_inventory.handle_item_drop(item_node, center_slot)

# 드래그 중 회전
func rotate_item():
	item_node.orientation = (item_node.orientation + 1) % 4
	update_rotation()

# 제자리 회전 (공간 제약 확인)
func rotate_item_in_place():
	var original_ori = item_node.orientation
	var new_ori = (original_ori + 1) % 4
	var inventory = item_node.parent_inventory
	
	if not inventory:
		return

	item_node.orientation = new_ori
	inventory.clear_slots(item_node, item_node.previous_center_slot)
	
	if inventory.can_place_item(item_node, item_node.previous_center_slot):
		inventory.mark_slots_as_full(item_node, item_node.previous_center_slot)
		inventory.update_item_state(item_node)
		update_rotation()
	else:
		item_node.orientation = original_ori
		inventory.mark_slots_as_full(item_node, item_node.previous_center_slot)

func update_rotation():
	var rot_rad = item_node.orientation * PI / 2
	rotation = rot_rad
	pivot_offset = size / 2
	
	# 가이드 회전 및 피벗 재확인
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.texture.rotation = rot_rad
		drag_preview.texture.pivot_offset = full_size / 2 # 피벗 강제 재설정
		
	# 커서 비주얼 회전 및 피벗 재확인
	if cursor_visual and is_instance_valid(cursor_visual):
		cursor_visual.rotation = rot_rad
		cursor_visual.pivot_offset = full_size / 2 # 피벗 강제 재설정
		
	update_drag_preview_position()

func end_drag():
	is_dragging = false
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	if cursor_visual:
		cursor_visual.queue_free()
		cursor_visual = null
	set_process(false)

func find_inventory_at_position(pos: Vector2) -> Node:
	for inv_id in Apeloot.inventory_refs.keys():
		var inv = Apeloot.inventory_refs[inv_id]
		var rect = inv.get_global_rect()
		if rect.has_point(pos):
			print("DEBUG: Found inventory ", inv_id, " for pos ", pos)
			return inv
	return null

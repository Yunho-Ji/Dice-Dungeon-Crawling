extends PanelContainer
class_name GridInventory

# 인벤토리 ID
@export var id := ""
# 인벤토리 슬롯 개수
@export var slot_count := 30:
	set(val):
		slot_count = val
		_reset()
# 인벤토리 열 개수
@export var columns := 10
# 단일 슬롯 모드 여부
@export var single_slot := false
# 전체 크기 모드 여부
@export var full_size := false
# 픽업 전용 모드 여부
@export var pickup_only := false
# 타입 전용 모드 여부
@export var type_only := false
# 슬롯 배경 텍스처
@export var slot_background : CompressedTexture2D
# 슬롯 아이콘 텍스처
@export var slot_icon : CompressedTexture2D
# 슬롯 간 간격
@export var slot_separation := Vector2(0,0)

# 아이템이 배치될 때 발생하는 신호
signal item_placed(item: DraggableItem)
# 아이템이 업데이트될 때 발생하는 신호
signal item_updated(item: DraggableItem)
# 아이템이 제거될 때 발생하는 신호
signal item_removed(item: DraggableItem)
# 아이템이 다른 인벤토리로 이동될 때 발생하는 신호
signal item_moved(item: DraggableItem, to_inventory: GridInventory)
# 아이템의 부모가 변경될 때 발생하는 신호
signal item_reparented(item: DraggableItem, new_parent: GridInventory)

# 그리드 컨테이너
var grid: GridContainer
# 아이템 노드
var items_node: Control
# 아이템 참조 목록
var items = []
# 아이템 상태 데이터 (저장/로드용)
var item_states = []

# 노드가 준비될 때 호출
func _ready():
	print("DEBUG: InventoryInterface _ready called. ID: ", id)
	initialize_inventory()

# 저장된 데이터로 인벤토리 로드
func load_inventory(data: Dictionary):
	initialize_inventory(data.inventories[id])

# 인벤토리 초기화
func initialize_inventory(states: Array = item_states):
	print("DEBUG: initialize_inventory called. Slot count: ", slot_count)
	_reset()
	reconstruct_grid_from_states(states)

# 노드가 트리에서 들어갈 때 호출
func _enter_tree():
	print("DEBUG: InventoryInterface _enter_tree called. ID: ", id)
	Apeloot.inventory_refs[id] = self

# 노드가 트리에서 나갈 때 호출
func _exit_tree():
	Apeloot.inventory_refs.erase(id)

# 인벤토리 리셋
func _reset():
	for c in get_children():
		c.queue_free()
	construct_children()
	drawSlots()

# 자식 노드 구성
func construct_children():
	print("DEBUG: construct_children called.")
	var scroll_scene := preload("res://addons/apeloot/inventory/grid_inventory/scroll_container.tscn")
	var scroll_node := scroll_scene.instantiate()
	add_child(scroll_node)
	grid = scroll_node.get_node("PanelContainer/InventoryGrid")
	grid.add_theme_constant_override("h_separation", slot_separation.x)
	grid.add_theme_constant_override("v_separation", slot_separation.y)
	items_node = scroll_node.get_node("PanelContainer/Items")
	var row_count = slot_count / columns
	grid.columns = columns
	# 중요: PanelContainer가 크기를 제어하도록 min size 설정 로직 수정 필요할 수 있음
	if full_size:
		custom_minimum_size = Vector2(0, (Apeloot.INVENTORY_ITEM_SIZE.y + grid.get_theme_constant("v_separation") + 1) * row_count)

# 슬롯 그리기
func drawSlots():
	print("DEBUG: drawSlots called. Creating ", slot_count, " slots.")
	var slotScene := preload("res://addons/apeloot/inventory/item_slot/item_slot.tscn")
	for i in range(slot_count):
		var slot := slotScene.instantiate()
		slot.parent_inventory = self
		slot.slot_id = i
		# slot.slotClicked.connect(slot_click) # for debug
		grid.add_child(slot)

# 아이템 위치 계산
func calculate_item_position(item, center_slot, global=true):
	var pattern = get_rotated_pattern(item)
	var pattern_width = len(pattern[0]) if not single_slot else 1
	var pattern_height = len(pattern) if not single_slot else 1
	var slot_size = grid.get_child(0).size
	var center_slot_global_position = grid.get_child(center_slot).global_position if global else grid.get_child(center_slot).position
	var offset_x = pattern_width / 2.0 if pattern_width % 2 == 0 else (pattern_width - 1) / 2.0
	var offset_y = pattern_height / 2.0 if pattern_height % 2 == 0 else (pattern_height - 1) / 2.0
	var global_item_position = center_slot_global_position - Vector2(offset_x, offset_y) * slot_size
	return global_item_position if global else grid.position + global_item_position

# 저장된 상태로부터 그리드 재구성
func reconstruct_grid_from_states(saved_states):
	for item in items:
		remove_item(item)
	items.clear()
	item_states.clear()
	for slot in grid.get_children():
		slot.full = false
	for state in saved_states:
		var item = spawn_item(state.id, state.stack_count)
		for prop in item.saved_props:
			item.set(prop, state.get(prop))
		mark_slots_as_full(item, state.previous_center_slot)
		items.append(item)
		item_states.append(state)

# 아이템 생성
func spawn_item(item_id, stack_count = 1):
	var item_scene = preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item = item_scene.instantiate()
	item.id = item_id
	item.parent_inventory = self
	items_node.add_child(item)
	return item

# 아이템 배치 가능 여부 확인
func can_place_item(item, center_slot_id):
	if pickup_only:
		return false
	if center_slot_id == -1:
		return false
	if type_only:
		pass
		# 여기에 타입 체크 로직 구현
	if single_slot:
		return false if get_slot_by_index(center_slot_id).full else true
	var pattern = get_rotated_pattern(item)
	var pattern_width = len(pattern[0])
	var pattern_height = len(pattern)
	var grid_width = grid.columns
	var grid_height = slot_count / grid_width
	var start_slot_x = center_slot_id % grid_width - int(pattern_width / 2.0)
	var start_slot_y = center_slot_id / grid_width - int(pattern_height / 2.0)
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern[y][x] == 1:
				var slot_x = start_slot_x + x
				var slot_y = start_slot_y + y
				var slot_id = slot_y * grid_width + slot_x
				if slot_x < 0 or slot_y < 0 or slot_x >= grid_width or slot_y >= grid_height:
					return false
				var slot = grid.get_child(slot_id)
				if slot.full:
					return false
	return true

# 아이템을 그리드에 맞춤
func snap_item_to_grid(item, center_slot):
	item.position = calculate_item_position(item, center_slot, false)
	item.previous_center_slot = center_slot
	if not items.has(item):
		items.append(item)
	mark_slots_as_full(item, center_slot)
	update_item_state(item)

# 아이템 상태 업데이트
func update_item_state(item: DraggableItem):
	var item_state = {}
	for prop in item.saved_props:
		item_state[prop] = item.get(prop)
	var existing_index = -1
	for i in range(item_states.size()):
		if item_states[i].instance_id == item.instance_id:
			existing_index = i
			break
	if existing_index != -1:
		item_states[existing_index] = item_state
	else:
		item_states.append(item_state)
	item_updated.emit(item)
	Apeloot.item_updated.emit(self, item)

# 아이템이 차지하는 슬롯 목록 가져오기
func get_occupied_slots(item, center_slot_id):
	if single_slot:
		return [center_slot_id]
	var occupied_slots = []
	var pattern_data = get_rotated_pattern(item)
	var pattern_width = len(pattern_data[0])
	var pattern_height = len(pattern_data)
	var grid_width = grid.columns
	var start_slot_x = center_slot_id % grid_width - int(pattern_width / 2.0)
	var start_slot_y = center_slot_id / grid_width - int(pattern_height / 2.0)
	for y in range(pattern_height):
		for x in range(pattern_width):
			if pattern_data[y][x] == 1:
				var slot_x = start_slot_x + x
				var slot_y = start_slot_y + y
				var slot_id = slot_y * grid_width + slot_x
				if slot_x >= 0 and slot_y >= 0 and slot_x < grid_width and slot_id < grid.get_child_count():
					occupied_slots.append(slot_id)
	return occupied_slots

# 회전된 아이템 패턴 가져오기
func get_rotated_pattern(item):
	var original_pattern = Apeloot.item_patterns[Apeloot.items[item.id]["pattern"]] if "pattern" in Apeloot.items[item.id] else Apeloot.item_patterns["1x1"]
	var rotated_pattern = []
	match item.orientation:
		0:  # 회전 없음
			return original_pattern
		1:  # 시계 방향 90도
			for x in range(len(original_pattern[0])):
				var new_row = []
				for y in range(len(original_pattern) - 1, -1, -1):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
		2:  # 180도
			for y in range(len(original_pattern) - 1, -1, -1):
				var new_row = []
				for x in range(len(original_pattern[0]) - 1, -1, -1):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
		3:  # 시계 방향 270도 (반시계 90도)
			for x in range(len(original_pattern[0]) - 1, -1, -1):
				var new_row = []
				for y in range(len(original_pattern)):
					new_row.append(original_pattern[y][x])
				rotated_pattern.append(new_row)
	return rotated_pattern

# 슬롯을 '가득 참'으로 표시
func mark_slots_as_full(item, center_slot_id: int):
	var occupied_slots = get_occupied_slots(item, center_slot_id)
	for slot_id in occupied_slots:
		var slot = grid.get_child(slot_id)
		slot.occupying_item = item
		slot.full = true

# 슬롯 비우기
func clear_slots(item, center_slot_id: int):
	var occupied_slots = get_occupied_slots(item, center_slot_id)
	for slot_id in occupied_slots:
		var slot = grid.get_child(slot_id)
		slot.occupying_item = null
		slot.full = false

# 아이템 상태 제거
func remove_item_state(item):
	var index_to_remove = -1
	for i in range(item_states.size()):
		if item_states[i].instance_id == item.instance_id:
			index_to_remove = i
			break
	if index_to_remove != -1:
		item_states.remove_at(index_to_remove)

# 아이템 등록 해제
func deregister_item(item):
	item_removed.emit(item)
	Apeloot.item_removed.emit(self, item)
	clear_slots(item, item.previous_center_slot)
	remove_item_state(item)
	items.erase(item)

# 아이템 제거
func remove_item(item):
	deregister_item(item)
	if is_instance_valid(item):
		item.queue_free()

# 아이템 드롭 처리
func handle_item_drop(dragged_item: DraggableItem, target_slot):
	var target_item = get_item_at_slot(target_slot)
	var drop_successful = true
	# 경우 1: 픽업 전용 모드
	if pickup_only:
		_reset_dragged_item(dragged_item)
		_end_drag(dragged_item)
		return drop_successful
	# 경우 2: 자기 자신 위에 드롭
	if target_item and target_item.instance_id == dragged_item.instance_id:
		_reset_dragged_item(dragged_item)
		_end_drag(dragged_item)
		return drop_successful
	# 경우 3: 아이템 합치기 (스택)
	if target_item and target_item.id == dragged_item.id and target_item.can_stack:
		_process_stack(dragged_item, target_item)
		_end_drag(dragged_item)
		return drop_successful
	# 경우 4: 아이템 병합
	if target_item and target_item.can_merge_with(dragged_item):
		_merge_items(dragged_item, target_item)
		_end_drag(dragged_item)
		return drop_successful
	# 경우 5: 일반적인 배치
	if can_place_item(dragged_item, target_slot):
		_place_item(dragged_item, target_slot)
	else:
		_reset_dragged_item(dragged_item)
	dragged_item.parent_inventory.item_placed.emit(dragged_item)
	Apeloot.item_added.emit(dragged_item.parent_inventory, dragged_item)
	_end_drag(dragged_item)
	return drop_successful

# 드래그된 아이템 리셋
func _reset_dragged_item(dragged_item: DraggableItem):
	dragged_item.orientation = dragged_item.original_orientation
	dragged_item.parent_inventory.snap_item_to_grid(dragged_item, dragged_item.previous_center_slot)

# 아이템 스택 처리
func _process_stack(dragged_item: DraggableItem, target_item):
	var remainder = target_item.add_to_stack(dragged_item.stack_count)
	if remainder == 0:
		_remove_dragged_item(dragged_item)
	else:
		dragged_item.stack_count = remainder
		_reset_dragged_item(dragged_item)
	update_item_state(target_item)

# 아이템 병합 처리
func _merge_items(dragged_item: DraggableItem, target_item):
	_remove_dragged_item(dragged_item)
	target_item.increase_rarity()
	update_item_state(target_item)

# 아이템 배치
func _place_item(dragged_item: DraggableItem, target_slot):
	if dragged_item.parent_inventory != self:
		if dragged_item.parent_inventory:
			dragged_item.parent_inventory.item_moved.emit(dragged_item, self)
		dragged_item.parent_inventory.item_reparented.emit(dragged_item, self)
		dragged_item.reparent(items_node)
		dragged_item.parent_inventory = self
	dragged_item.parent_inventory.snap_item_to_grid(dragged_item, target_slot)

# 드래그된 아이템 제거
func _remove_dragged_item(dragged_item: DraggableItem):
	if dragged_item.parent_inventory != self:
		dragged_item.parent_inventory.item_moved.emit(dragged_item, self)
	dragged_item.parent_inventory.remove_item(dragged_item)

# 드래그 종료
func _end_drag(dragged_item: DraggableItem):
	if is_instance_valid(dragged_item) and dragged_item.get_node("ItemTexture"):
		dragged_item.get_node("ItemTexture").end_drag()

# 특정 슬롯의 아이템 가져오기
func get_item_at_slot(slot_id):
	for item in items:
		if item.previous_center_slot == slot_id:
			return item
	return null

# 특정 위치의 슬롯 찾기
func find_slot_at_position(pos: Vector2) -> int:
	for i in range(grid.get_child_count()):
		var slot = grid.get_child(i)
		if slot.get_global_rect().has_point(pos):
			return i
	return -1

# 인덱스로 슬롯 가져오기
func get_slot_by_index(idx):
	var slot = grid.get_child(idx)
	return slot if slot else null

# 슬롯이 점유되었는지 확인
func is_slot_occupied(idx):
	return get_slot_by_index(idx).full

# 특정 위치의 아이템 가져오기
func get_item_at_position(pos: Vector2) -> Node:
	for item in items:
		if item.get_node("ItemTexture").get_global_rect().has_point(pos):
			return item
	return null

# 유효한 슬롯 찾기
func find_valid_slot(item) -> int:
	for i in range(grid.get_child_count()):
		if can_place_item(item, i):
			return i
	return -1

# 아이템을 배치할 수 있는지 확인하고 배치
func try_fit_and_place(item: DraggableItem) -> bool:
	var fit_slot = fit_given_item(item)
	if fit_slot != -1:
		_place_item(item, fit_slot)
		return true
	return false

# 주어진 아이템에 맞는 슬롯 찾기
func fit_given_item(item: DraggableItem) -> int:
	for slot_id in range(grid.get_child_count()):
		if can_place_item(item, slot_id):
			return slot_id
	return -1

# --- 디버그 함수 ---
# 슬롯 클릭 (디버그용)
func slot_click(slot_id):
	if is_slot_occupied(slot_id):
		return
	var item = spawn_random_item()
	var can_place = can_place_item(item, slot_id)
	if can_place:
		snap_item_to_grid(item, slot_id)
	else:
		item.queue_free()

# 무작위 아이템 생성 (디버그용)
func spawn_random_item():
	var itemSc := preload("res://addons/apeloot/inventory/item_draggable/item_draggable.tscn")
	var item := itemSc.instantiate()
	item.id = Apeloot.items.keys().pick_random()
	item.parent_inventory = self
	items_node.add_child(item)
	return item

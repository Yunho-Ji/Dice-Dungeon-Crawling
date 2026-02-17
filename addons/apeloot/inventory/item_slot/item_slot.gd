extends PanelContainer

# 슬롯 클릭 시 발생하는 신호 (슬롯 ID 전달)
signal slotClicked(slotId)

# 애니메이션 플레이어 노드 참조
var anim_player : AnimationPlayer:
	get:
		return $AnimationPlayer
		
# 부모 인벤토리 참조 및 설정
var parent_inventory: # 타입을 제거하여 유연성 확보
	set(val):
		parent_inventory = val
		if not val: return
		# 부모 인벤토리의 배경 텍스처가 있으면 슬롯 배경 설정
		if "slot_background" in val and val.slot_background:
			$Background.texture = val.slot_background
		# 부모 인벤토리의 아이콘 텍스처가 있으면 슬롯 아이콘 설정
		if "slot_icon" in val and val.slot_icon:
			$Icon.texture = val.slot_icon
			
# 슬롯을 점유하는 아이템 참조 및 설정
var occupying_item: DraggableItem = null:
	set(val):
		# 아이템이 슬롯에 있을 경우
		if val:
			# 기존 아이템과 다르면 업그레이드 신호 연결
			if val != occupying_item:
				val.itemUpgraded.connect(refresh_props)
			$Icon.visible = false # 아이콘 숨김
			$Background.modulate = val.get_rarity_data()["color"] # 배경 색상 변경 (아이템 희귀도에 따라)
			mouse_default_cursor_shape = CURSOR_POINTING_HAND # 마우스 커서 변경
		# 아이템이 슬롯에 없을 경우
		else	:
			# 기존 아이템이 유효하면 업그레이드 신호 연결 해제
			if is_instance_valid(occupying_item):
				occupying_item.itemUpgraded.disconnect(refresh_props)
			can_drag = true # 드래그 가능 설정
			$Icon.visible = true # 아이콘 표시
			$Background.modulate = Color("b2b2b2") # 배경 색상 초기화
			mouse_default_cursor_shape = CURSOR_ARROW # 마우스 커서 초기화
		occupying_item = val # 점유 아이템 업데이트
		
# 드래그 가능 여부
var can_drag := true:
	set(val):
		can_drag = val
		$Blocked.visible = not val # 차단 이미지 가시성 설정
# 슬롯 ID
var slot_id := -1
# 슬롯이 가득 찼는지 여부
var full := false
# 표시 중인 툴팁 노드
var showing_tooltip: HBoxContainer

# 매 프레임마다 호출
func _process(delta):
	# 툴팁이 표시 중이면 위치 조정
	if showing_tooltip:
		adjust_tooltip_pos()

# 드래그 데이터 가져오기
func _get_drag_data(_at_position):
	# 점유 아이템이 있고 드래그 가능하면 아이템 드래그 시작
	if occupying_item and can_drag:
		occupying_item.texture.drag_item()

# GUI 입력 이벤트 처리
func _on_gui_input(event: InputEvent):
	# 마우스 왼쪽 버튼 클릭 시 슬롯 클릭 신호 발생
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			slotClicked.emit(slot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 우클릭 시 아이템 버리기 (확인 절차 없이 즉시 삭제 - 테스트 편의성)
			if occupying_item:
				print("DEBUG: ItemSlot: 아이템 버리기 요청 - ", occupying_item.id)
				parent_inventory.remove_item(occupying_item)
				hide_tooltip()

# 드롭 데이터 수락 가능 여부 확인
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# 데이터가 딕셔너리가 아니거나 "item" 키가 없으면 false 반환
	if not data is Dictionary or not "item" in data:
		return false
	var item = data["item"] # 드롭된 아이템 가져오기
	# 드롭 위치의 중앙 슬롯 ID 찾기
	var center_slot = parent_inventory.find_slot_at_position(at_position)
	# 부모 인벤토리에서 아이템 배치 가능 여부 확인
	return parent_inventory.can_place_item(item, center_slot)

# 데이터 드롭 처리
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var item = data["item"] # 드롭된 아이템 가져오기
	# 드롭 위치의 중앙 슬롯 ID 찾기
	var center_slot = parent_inventory.find_slot_at_position(at_position)
	# 부모 인벤토리에서 아이템 드롭 처리
	parent_inventory.handle_item_drop(item, center_slot)

# 속성 새로 고침
func refresh_props() -> void:
	occupying_item = occupying_item # 점유 아이템 속성 새로 고침

# 마우스 진입 시 호출
func _on_mouse_entered():
	show_tooltip() # 툴팁 표시

# 마우스 이탈 시 호출
func _on_mouse_exited():
	hide_tooltip() # 툴팁 숨김

# 툴팁 표시
func show_tooltip():
	# 점유 아이템이 유효하면 툴팁 생성 및 표시
	if is_instance_valid(occupying_item):
		var tooltip_cont := HBoxContainer.new()
		var tooltip = spawn_tooltip(occupying_item)
		tooltip_cont.add_child(tooltip)
		tooltip_cont.z_index = 10
		Apeloot.temp_node.add_child(tooltip_cont)
		showing_tooltip = tooltip_cont

# 툴팁 생성
func spawn_tooltip(for_item) -> ItemTooltip:
	var tooltip_scene := preload("res://addons/apeloot/inventory/item_tooltip/item_tooltip.tscn")
	var tooltip := tooltip_scene.instantiate()
	tooltip.item_ref = for_item
	return tooltip

# 툴팁 숨김
func hide_tooltip():
	# 툴팁이 유효하면 해제
	if is_instance_valid(showing_tooltip):
		showing_tooltip.queue_free()
		showing_tooltip = null

# 툴팁 위치 조정
func adjust_tooltip_pos():
	var screen_size = get_viewport().get_visible_rect().size # 화면 크기
	var tooltip_size = showing_tooltip.get_rect().size # 툴팁 크기
	var mouse_position = get_global_mouse_position() # 마우스 전역 위치
	var new_position = mouse_position + Vector2(15, 15) # 새로운 툴팁 위치 (오프셋 적용)
	# 툴팁이 화면 오른쪽을 넘어가는지 확인
	if new_position.x + tooltip_size.x > screen_size.x:
		new_position.x = mouse_position.x - tooltip_size.x - 15  # 왼쪽으로 이동
	# 툴팁이 화면 아래쪽을 넘어가는지 확인
	if new_position.y + tooltip_size.y > screen_size.y:
		new_position.y = mouse_position.y - tooltip_size.y - 15  # 위로 이동
	showing_tooltip.position = new_position # 툴팁 위치 설정

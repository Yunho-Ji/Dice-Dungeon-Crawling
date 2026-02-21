extends PanelContainer

signal closed

# UI Components
var target_slot_panel: PanelContainer
var dice_list_container: HBoxContainer
var result_label: Label
var enchant_button: Button
var target_item_label: Label

# Data
var current_target_item: DraggableItem = null # 현재 슬롯에 올라간 아이템 노드
var selected_dice_index: int = -1 # 선택된 주사위 인덱스
var selected_dice_sides: int = 0

func _ready():
	# Apeloot 드롭 수신 등록
	Apeloot.inventory_refs["enchant_screen"] = self
	
	custom_minimum_size = Vector2(600, 500)
	
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "--- 아이템 강화 (주사위 소모) ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	# 1. Target Item Slot (Drop Zone)
	target_slot_panel = PanelContainer.new()
	target_slot_panel.custom_minimum_size = Vector2(0, 100)
	var slot_label = Label.new()
	slot_label.text = "강화할 장비를 이곳에 드래그하세요"
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	target_slot_panel.add_child(slot_label)
	main_vbox.add_child(target_slot_panel)
	
	target_item_label = Label.new()
	target_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(target_item_label)
	
	# 2. Dice Selection
	var dice_label = Label.new()
	dice_label.text = "소모할 주사위 선택:"
	main_vbox.add_child(dice_label)
	
	dice_list_container = HBoxContainer.new()
	dice_list_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(dice_list_container)
	
	_refresh_dice_list()
	
	# 3. Action Button
	enchant_button = Button.new()
	enchant_button.text = "강화 시작 (주사위 소모)"
	enchant_button.disabled = true
	enchant_button.pressed.connect(_on_enchant_pressed)
	main_vbox.add_child(enchant_button)
	
	# 4. Result
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(result_label)
	
	# Close
	var close_btn = Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)

func _refresh_dice_list():
	for c in dice_list_container.get_children():
		c.queue_free()
		
	var pool = DiceManager.get_player_dice_pool()
	for i in range(pool.size()):
		var sides = pool[i]
		var btn = Button.new()
		btn.text = "D%d" % sides
		btn.toggle_mode = true
		btn.pressed.connect(_on_dice_selected.bind(i, sides, btn))
		dice_list_container.add_child(btn)

func _on_dice_selected(idx: int, sides: int, btn: Button):
	selected_dice_index = idx
	selected_dice_sides = sides
	
	# 다른 버튼 토글 해제
	for child in dice_list_container.get_children():
		if child != btn:
			child.set_pressed_no_signal(false)
			
	_update_enchant_button()

func _update_enchant_button():
	enchant_button.disabled = (current_target_item == null or selected_dice_index == -1)

# Apeloot 드롭 핸들러
func handle_item_drop(dragged_item, _target_slot):
	# 이미 아이템이 있다면 기존 아이템을 인벤토리로 반환 (또는 교체)
	if current_target_item:
		_return_item_to_inventory(current_target_item)
	
	# 드래그된 아이템을 슬롯의 자식으로 가져옴
	if dragged_item.parent_inventory:
		dragged_item.parent_inventory.remove_item(dragged_item)
	
	dragged_item.get_parent().remove_child(dragged_item)
	target_slot_panel.add_child(dragged_item)
	
	# 위치 중앙 정렬
	dragged_item.position = (target_slot_panel.size / 2.0) - (dragged_item.get_node("ItemTexture").size / 2.0)
	
	current_target_item = dragged_item
	target_item_label.text = Apeloot.items[dragged_item.id].get("name", "Unknown Item")
	
	_update_enchant_button()
	return true # 드롭 성공

func _return_item_to_inventory(item):
	# PlayerManager의 대기열이나 인벤토리로 되돌리기
	# 여기서는 간단히 삭제하고 PlayerManager 대기열에 추가 (안전하게)
	var id = item.id
	item.queue_free()
	if PlayerManager:
		PlayerManager.add_pending_item(id)
	current_target_item = null
	target_item_label.text = ""

func _on_enchant_pressed():
	if not current_target_item or selected_dice_index == -1: return
	
	enchant_button.disabled = true
	result_label.text = "주사위를 굴리는 중..."
	
	# 주사위 굴림 연출 (간단히 타이머 사용)
	await get_tree().create_timer(1.0).timeout
	
	var roll_result = randi_range(1, selected_dice_sides)
	result_label.text = "주사위 결과: %d!" % roll_result
	
	await get_tree().create_timer(0.5).timeout
	
	# 강화 로직 실행
	var item_data = Apeloot.items[current_target_item.id] # 원본 데이터 참조 (주의: 인스턴스 데이터여야 함)
	# Apeloot 구조상 dragged_item.stats 에 인스턴스 스탯이 있을 것임
	
	# 임시 딕셔너리 생성해서 매니저에 전달
	var enchant_data = {
		"name": item_data.get("name", ""),
		"grade": current_target_item.rarity, # Apeloot 변수명 확인 필요 (rarity vs grade)
		"stats": current_target_item.stats # 인스턴스 스탯
	}
	
	# 매니저 호출
	# Autoload 접근 안정성을 위해 get_node 사용
	var enchant_manager = get_node("/root/EnchantManager")
	if not enchant_manager:
		printerr("EnchantScreen: EnchantManager Autoload를 찾을 수 없습니다!")
		enchant_button.disabled = false
		return
		
	var success = enchant_manager.enchant_item(enchant_data, roll_result)
	
	if success:
		result_label.text += "
강화 성공! 스탯이 상승했습니다."
		# 주사위 소모
		DiceManager.player_dice_pool.remove_at(selected_dice_index)
		_refresh_dice_list()
		selected_dice_index = -1
		
		# 아이템 정보 갱신 (툴팁 등)
		current_target_item.stats = enchant_data.stats
		# 등급 변화 반영
		# current_target_item.rarity = enchant_data.grade 
		
	else:
		result_label.text += "
강화 실패..."
		# 실패 시 주사위는 소모되지 않는가? 기획 확인 필요. 
		# "선택된 주사위는 주사위 굴리기 시 주사위풀에서 삭제된다" -> 실패해도 삭제됨
		DiceManager.player_dice_pool.remove_at(selected_dice_index)
		_refresh_dice_list()
		selected_dice_index = -1

	enchant_button.disabled = false
	_update_enchant_button()

func _on_close_pressed():
	if current_target_item:
		_return_item_to_inventory(current_target_item)
	
	if Apeloot.inventory_refs.get("enchant_screen") == self:
		Apeloot.inventory_refs.erase("enchant_screen")
		
	closed.emit()
	queue_free()

# Apeloot 호환성
func can_place_item(_item, _slot_id) -> bool: return true

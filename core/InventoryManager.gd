extends Node

# 인벤토리 시스템과 외부 시스템(골드, 아이템 사용 등) 간의 중재자
# 데이터 무결성을 보장하고 트랜잭션 처리를 담당합니다.

# =============================================================================
# 골드 관리 및 금화 더미 로직
# =============================================================================

func _ready() -> void:
	# EconomyManager에 골드 검증 로직 주입 (의존성 역전)
	if EconomyManager:
		EconomyManager.gold_validator = self.calculate_allowed_gold

func _exit_tree() -> void:
	# 안전하게 연결 해제
	if EconomyManager and EconomyManager.gold_validator == self.calculate_allowed_gold:
		EconomyManager.gold_validator = Callable()

# 플레이어의 골드 변경 요청을 처리하고, 인벤토리 상황에 맞춰 실제 적용 가능한 골드량을 반환합니다.
# projected_gold: 변경 후 예상되는 총 골드량
func calculate_allowed_gold(current_gold: int, projected_gold: int) -> int:
	var inventory = Apeloot.inventory_refs.get("player_inventory")
	if not inventory:
		printerr("InventoryManager: player_inventory를 찾을 수 없습니다.")
		return projected_gold # 인벤토리가 없으면 제한 없이 적용 (예외 처리)

	# 1. 목표 아이템 ID 결정
	var target_item_id = _get_target_gold_item_id(projected_gold)
	var current_item_id = _get_target_gold_item_id(current_gold)

	# 2. 아이템 등급에 변화가 없으면 승인
	if target_item_id == current_item_id:
		return projected_gold

	# 3. 아이템 등급이 낮아지는 경우 (소비) -> 무조건 승인 및 아이템 다운그레이드 처리
	if projected_gold < current_gold:
		_update_gold_item_visual(inventory, target_item_id)
		return projected_gold

	# 4. 아이템 등급이 높아지는 경우 (획득) -> 공간 검증 필요
	# 기존 금화 아이템을 찾습니다.
	var existing_item = _find_gold_item(inventory)
	
	# 시뮬레이션: 업그레이드 가능 여부 확인
	if _can_upgrade_gold_item(inventory, existing_item, target_item_id):
		# 성공: 실제 아이템 교체 수행
		_update_gold_item_visual(inventory, target_item_id, existing_item)
		return projected_gold
	else:
		# 실패: 공간 부족 -> 업그레이드 취소 및 골드 롤백 (임계값 - 1G)
		# 예: 10,000G(4x4) 실패 시 -> 9,999G(3x3 유지)
		print("InventoryManager: 금화 더미 업그레이드 실패 (공간 부족). 골드가 롤백됩니다.")
		return _get_max_gold_for_tier(current_item_id)

func _get_target_gold_item_id(gold_amount: int) -> String:
	if gold_amount >= 10000: return "gold_pile_large" # 4x4
	if gold_amount >= 7500: return "gold_pile_medium" # 3x3
	if gold_amount >= 5000: return "gold_pile_small" # 2x2
	return ""

func _get_max_gold_for_tier(item_id: String) -> int:
	match item_id:
		"gold_pile_small": return 7499
		"gold_pile_medium": return 9999
		"": return 4999
	return 999999 # Should not happen

func _find_gold_item(inventory: GridInventory) -> DraggableItem:
	for item in inventory.items:
		if item.id.begins_with("gold_pile_"):
			return item
	return null

# 금화 아이템 업그레이드 가능 여부 시뮬레이션 (Atomic Check)
func _can_upgrade_gold_item(inventory: GridInventory, existing_item: DraggableItem, new_item_id: String) -> bool:
	# 새 아이템 생성을 위해 임시 인스턴스 생성
	var temp_item = inventory.spawn_item(new_item_id)
	temp_item.visible = false # 화면에 안 보이게
	
	var can_place = false
	
	if existing_item:
		# 기존 아이템이 있다면, 잠시 인벤토리에서 '논리적으로' 제거하고 공간을 체크해야 함
		# GridInventory의 로직을 우회하기 위해, 기존 아이템이 점유한 슬롯을 잠시 비움 처리
		var occupied_slots = inventory.get_occupied_slots(existing_item, existing_item.previous_center_slot)
		
		# 1. 슬롯 점유 해제 (가상)
		for slot_id in occupied_slots:
			inventory.get_child(0).get_node("PanelContainer/InventoryGrid").get_child(slot_id).full = false
			
		# 2. 새 아이템 배치 시도 (가상)
		if inventory.fit_given_item(temp_item) != -1:
			can_place = true
			
		# 3. 슬롯 점유 복구 (롤백)
		for slot_id in occupied_slots:
			inventory.get_child(0).get_node("PanelContainer/InventoryGrid").get_child(slot_id).full = true
			
	else:
		# 기존 아이템이 없으면 그냥 빈 공간 체크
		if inventory.fit_given_item(temp_item) != -1:
			can_place = true
			
	temp_item.queue_free() # 임시 아이템 삭제
	return can_place

# 실제 금화 아이템 교체/생성 실행
func _update_gold_item_visual(inventory: GridInventory, target_item_id: String, existing_item: DraggableItem = null):
	# 1. 기존 아이템이 있다면 위치를 기억하고 삭제
	var old_item = _find_gold_item(inventory) # 인자로 받아도 되지만 안전하게 다시 찾음
	var preferred_slot = -1
	
	if old_item:
		# 가능한 경우 같은 위치(중심점)를 선호하도록
		preferred_slot = old_item.previous_center_slot
		inventory.remove_item(old_item)
	
	# 2. 목표 아이템이 없다면(5000G 미만으로 떨어진 경우) 여기서 종료
	if target_item_id == "":
		return

	# 3. 새 아이템 생성 및 배치
	var new_item = inventory.spawn_item(target_item_id)
	
	# 선호 위치에 먼저 시도 (업그레이드 느낌)
	if preferred_slot != -1 and inventory.can_place_item(new_item, preferred_slot):
		inventory.snap_item_to_grid(new_item, preferred_slot)
	else:
		# 안되면 자동 배치
		if not inventory.try_fit_and_place(new_item):
			# 이론상 _can_upgrade_gold_item에서 검증했으므로 여기 올 일은 거의 없으나 안전장치
			new_item.queue_free()
			printerr("CRITICAL: InventoryManager - 검증된 배치 실패. 데이터 불일치 발생.")

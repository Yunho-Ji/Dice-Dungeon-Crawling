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
	# ... (생략된 기존 코드) ...
	pass

# [신규] 전역 아이템 추가 함수
# 성공 시 true, 공간 부족 시 false 반환 (하지만 대기열에 추가되므로 실질적으론 획득 성공)
func try_add_item(item_id: String) -> bool:
	var inventory = Apeloot.inventory_refs.get("player_inventory")
	var added_to_ui = false
	
	if inventory:
		var new_item = inventory.spawn_item(item_id)
		if inventory.try_fit_and_place(new_item):
			print("InventoryManager: 아이템 획득 성공 (UI) - ", item_id)
			added_to_ui = true
		else:
			new_item.queue_free()
			print("InventoryManager: 인벤토리 공간 부족 (UI) - ", item_id)
			# UI는 있지만 공간이 부족한 경우 -> 일단 대기열에 넣어서 나중에 처리하게 할지, 아니면 실패로 처리할지 결정 필요
			# 기획적으로 '우편함'이나 '바닥 떨구기'가 없다면 대기열에 넣는 것이 안전함.
	
	if not added_to_ui:
		# UI가 없거나 공간이 부족하면 대기열에 추가
		var player_manager = get_node_or_null("/root/GameManager/PlayerManager") # GameManager가 Autoload이므로 경로 조정
		# PlayerManager가 Autoload가 아니라 GameManager의 자식일 수 있음. 확인 필요.
		# 하지만 보통 PlayerManager는 별도 Autoload이거나 GameManager 내 변수임.
		# 현재 코드베이스에서는 GameManager.player_manager로 접근 가능.
		
		if GameManager.player_manager:
			GameManager.player_manager.add_pending_item(item_id)
			return true
		else:
			printerr("InventoryManager: PlayerManager를 찾을 수 없어 아이템 획득 실패 - ", item_id)
			return false
			
	return true

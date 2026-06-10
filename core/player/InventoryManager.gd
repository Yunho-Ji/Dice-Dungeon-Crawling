extends Node

# InventoryManager.gd
# 인벤토리 시스템과 외부 시스템(골드, 아이템 사용 등) 간의 중재자
# 데이터 무결성을 보장하고 트랜잭션 처리를 담당합니다.

# =============================================================================
# 드래그 앤 드롭 상태 관리
# =============================================================================

var dragging_item: InventoryItem = null
var dragging_source_node: Node = null

func start_drag(item: InventoryItem, source_node: Node):
	dragging_item = item
	dragging_source_node = source_node
	print("InventoryManager: Drag started - ", item.id)

func end_drag():
	dragging_item = null
	dragging_source_node = null
	print("InventoryManager: Drag ended")

func rotate_dragging_item():
	if dragging_item:
		dragging_item.is_rotated = !dragging_item.is_rotated
		print("InventoryManager: Dragging Item rotated - ", dragging_item.is_rotated)
		SignalBus.emit_signal("inventory_item_rotated", dragging_item)

func try_rotate_item_in_inventory(item: InventoryItem) -> bool:
	if not PlayerManager or not PlayerManager.inventory_data: return false
	
	if PlayerManager.inventory_data.try_rotate_item(item):
		print("InventoryManager: Inventory Item rotated - ", item.id)
		return true
	return false

# =============================================================================
# 골드 관리 및 금화 더미 로직 (기획 고도화 반영)
# =============================================================================

var gold_penalty_enabled: bool = true # 마을 업그레이드 등으로 비활성화 가능

# 골드 구간 설정
const GOLD_STEP_SMALL = 5000
const GOLD_STEP_MEDIUM = 15000
const GOLD_STEP_LARGE = 30000

func _ready() -> void:
	if EconomyManager:
		# EconomyManager에 골드 검증 로직 주입 (의존성 역전)
		EconomyManager.gold_validator = self.calculate_allowed_gold
		
		# 골드 변경 시마다 더미 동기화 시그널 연결
		if not SignalBus.gold_changed.is_connected(_on_gold_changed):
			SignalBus.gold_changed.connect(_on_gold_changed)

func _exit_tree() -> void:
	# 안전하게 연결 해제
	if EconomyManager and EconomyManager.gold_validator == self.calculate_allowed_gold:
		EconomyManager.gold_validator = Callable()

func calculate_allowed_gold(current_gold: int, projected_gold: int) -> int:
	if not gold_penalty_enabled or projected_gold <= current_gold: 
		return projected_gold
	
	var target_id = _get_target_gold_pile_id(projected_gold)
	if target_id == "": return projected_gold
	
	# 현재 소지한 더미가 목표 더미와 다를 경우 공간 확인 필요
	var current_pile = _get_current_gold_pile()
	if current_pile and current_pile.id == target_id:
		return projected_gold
		
	# 새 더미가 들어갈 공간이 있는지 시뮬레이션
	if PlayerManager.inventory_data.can_place_item_at(target_id, Vector2i(0,0), false, current_pile) or \
	   PlayerManager.inventory_data.find_free_space(target_id) != Vector2i(-1, -1):
		return projected_gold
	
	print("InventoryManager: 더 큰 금화 더미를 위한 공간이 부족합니다!")
	# 현재 단계에서 가질 수 있는 최대 골드 반환
	if projected_gold >= GOLD_STEP_LARGE: return GOLD_STEP_LARGE - 1
	if projected_gold >= GOLD_STEP_MEDIUM: return GOLD_STEP_MEDIUM - 1
	return GOLD_STEP_SMALL - 1

func _get_target_gold_pile_id(gold: int) -> String:
	if gold >= GOLD_STEP_LARGE: return "gold_pile_large"
	if gold >= GOLD_STEP_MEDIUM: return "gold_pile_medium"
	if gold >= GOLD_STEP_SMALL: return "gold_pile_small"
	return ""

func _get_current_gold_pile() -> InventoryItem:
	if not PlayerManager or not PlayerManager.inventory_data: return null
	for item in PlayerManager.inventory_data.items:
		if item.id.begins_with("gold_pile_"):
			return item
	return null

func sync_gold_piles():
	if not PlayerManager or not PlayerManager.inventory_data: return
	
	if not gold_penalty_enabled:
		var pile = _get_current_gold_pile()
		if pile: PlayerManager.inventory_data.remove_item(pile)
		return

	var gold = EconomyManager.get_gold()
	var target_id = _get_target_gold_pile_id(gold)
	var current_pile = _get_current_gold_pile()
	
	# 1. 제거가 필요한 경우 (골드 감소 등)
	if target_id == "":
		if current_pile: PlayerManager.inventory_data.remove_item(current_pile)
		return
		
	# 2. 교체가 필요한 경우 (단계 상승/하락)
	if current_pile and current_pile.id != target_id:
		PlayerManager.inventory_data.remove_item(current_pile)
		PlayerManager.inventory_data.add_item(target_id)
		print("InventoryManager: 금화 더미 단계 변경 -> ", target_id)
	
	# 3. 새로 생성해야 하는 경우
	elif not current_pile:
		PlayerManager.inventory_data.add_item(target_id)
		print("InventoryManager: 금화 더미 생성 -> ", target_id)

func _on_gold_changed(_new_amount: int, _delta: int):
	sync_gold_piles()

# =============================================================================
# 아이템 관리 트랜잭션
# =============================================================================

# 전역 아이템 추가 함수
# 성공 시 true, 공간 부족 시 false 반환
func try_add_item(item_id: String) -> bool:
	if not PlayerManager or not PlayerManager.inventory_data: return false
	
	# 신규 인벤토리 데이터 모델에 직접 추가 시도
	if PlayerManager.inventory_data.add_item(item_id):
		print("InventoryManager: 아이템 획득 성공 (Model) - ", item_id)
		return true
	
	print("InventoryManager: 인벤토리 공간 부족 - ", item_id)
	return false # 획득 실패 알림

# 아이템 판매 함수
func sell_item(item: InventoryItem):
	if not PlayerManager or not PlayerManager.inventory_data: return
	
	var item_def = item.get_data()
	# 가격 계산 (기본 가격의 50%를 판매가로 가정, 최소 1G)
	var buy_price = 0
	if item_def.has("price"):
		buy_price = int(item_def.price)
	else:
		# 등급별 기본 가격 로직 (상점과 동일하게 유지)
		var grade = item_def.get("grade", "common")
		match grade:
			"common": buy_price = 50
			"rare": buy_price = 200
			"epic": buy_price = 800
			"relic": buy_price = 2500
			_: buy_price = 100
			
	var sell_price = max(1, int(buy_price * 0.5))
	
	# 인벤토리에서 제거 후 골드 지급
	PlayerManager.inventory_data.remove_item(item)
	EconomyManager.add_gold(sell_price)
	
	print("InventoryManager: 아이템 판매 완료 - ", item.id, " (+", sell_price, "G)")
	SignalBus.emit_signal("inventory_updated")

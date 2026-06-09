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
func calculate_allowed_gold(_current_gold: int, projected_gold: int) -> int:
	return projected_gold # 임시로 모든 골드 변경 승인

# [TODO] 신규 인벤토리 시스템에 맞게 골드 더미 로직 재구현 필요
# func _get_target_gold_item_id(gold_amount: int) -> String:
# 	if gold_amount >= 10000: return "gold_pile_large" # 4x4
# 	if gold_amount >= 7500: return "gold_pile_medium" # 3x3
# 	if gold_amount >= 5000: return "gold_pile_small" # 2x2
# 	return ""

# [신규] 전역 아이템 추가 함수
# 성공 시 true, 공간 부족 시 false 반환
func try_add_item(item_id: String) -> bool:
	if not PlayerManager: return false
	
	# 신규 인벤토리 데이터 모델에 직접 추가 시도
	if PlayerManager.inventory_data.add_item(item_id):
		print("InventoryManager: 아이템 획득 성공 (Model) - ", item_id)
		return true
	
	print("InventoryManager: 인벤토리 공간 부족 - ", item_id)
	return false # 획득 실패 알림

# LootManager.gd
# 역할: 전투 후 발생하는 전리품 데이터를 관리하고, 플레이어의 획득 요청을 안전하게 처리하는 매니저입니다.
extends Node

signal loot_updated # 전리품 상태가 변경되었을 때 (아이템 획득 등)
signal reward_claimed(type, data) # 특정 보상이 성공적으로 지급되었을 때

var current_loot = {
	"gold": 0,
	"items": [],
	"dice": [],
	"is_boss": false
}

# 새로운 전리품 설정
func set_pending_loot(loot_data: Dictionary):
	current_loot = loot_data
	print("LootManager: 새로운 전리품 등록 완료")

# 특정 아이템 획득 시도
func claim_item(item_data: Dictionary) -> bool:
	var item_id = item_data.get("id", "")
	if item_id == "": return false
	
	# InventoryManager를 통해 실제 가방에 추가 시도
	if InventoryManager.try_add_item(item_id):
		# 성공 시 현재 전리품 목록에서 제거
		if current_loot.has("items") and current_loot["items"] is Array:
			current_loot["items"].erase(item_data)
		
		emit_signal("loot_updated")
		emit_signal("reward_claimed", "item", item_data)
		print("LootManager: 아이템 획득 성공 - ", item_id)
		return true
	
	print("LootManager: 아이템 획득 실패 (공간 부족 등) - ", item_id)
	return false

# 골드 및 주사위 등 모든 잔여 보상 일괄 획득 (확인 버튼 클릭 시)
func claim_remaining_rewards():
	# 골드 지급
	var gold = current_loot.get("gold", 0)
	if gold > 0:
		EconomyManager.add_gold(gold)
		current_loot["gold"] = 0
		emit_signal("reward_claimed", "gold", gold)
		
	# 주사위 지급
	var dice = current_loot.get("dice", [])
	if dice.size() > 0:
		for sides in dice:
			DiceManager.add_pending_reward(sides)
			DiceManager.confirm_reward(DiceManager.pending_rewards.size() - 1)
		current_loot["dice"] = []
		DiceManager.enable_roll()
		emit_signal("reward_claimed", "dice", dice)
		
	emit_signal("loot_updated")
	print("LootManager: 잔여 보상(골드/주사위) 처리 완료")

# 현재 남아있는 아이템이 있는지 확인
func has_remaining_items() -> bool:
	return current_loot.get("items", []).size() > 0

func get_loot_data() -> Dictionary:
	return current_loot

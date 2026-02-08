extends Node

@export var player_data: CharacterData # 플레이어의 캐릭터 데이터 리소스
var current_player_stats: MyCharacterStats # 전투 간 플레이어의 현재 스탯을 저장

# [신규] 장비 데이터 (10개 슬롯)
var equipment: Dictionary = {
	"head": null,
	"top": null,
	"bottom": null,
	"shoes": null,
	"left_hand": null,
	"right_hand": null,
	"accessory_1": null,
	"accessory_2": null,
	"accessory_3": null,
	"accessory_4": null
}

# [신규] 아이템 장착 함수
func equip_item(slot_key: String, item_data: Dictionary):
	if equipment.has(slot_key):
		# 기존 장비가 있다면 먼저 해제
		if equipment[slot_key]:
			unequip_item(slot_key)
			
		equipment[slot_key] = item_data
		_apply_equipment_stats(item_data, true)
		print("DEBUG: ", slot_key, " 부위에 ", item_data.get("name", "아이템"), " 장착 완료.")

# [신규] 아이템 해제 함수
func unequip_item(slot_key: String):
	if equipment.has(slot_key) and equipment[slot_key]:
		var item_data = equipment[slot_key]
		_apply_equipment_stats(item_data, false)
		equipment[slot_key] = null
		print("DEBUG: ", slot_key, " 부위 장비 해제 완료.")

# [신규] 장비 스탯 반영 로직 (구현 예정: MyStatModifier와 연동)
func _apply_equipment_stats(item_data: Dictionary, is_equipping: bool):
	if not current_player_stats: return
	# 아이템 데이터에 포함된 보너스 스탯을 플레이어 스탯에 가감합니다.
	# (현재는 구조 구축 단계이므로 로그만 출력)
	pass
# 기존 코드 호환성을 위해 래퍼 함수를 제공합니다.

func add_gold(amount: int):
	EconomyManager.add_gold(amount)

func get_gold() -> int:
	return EconomyManager.get_gold()

func _print_stats_debug_info(context: String):
	print("DEBUG: PlayerManager: --- Stats Debug Info (Context: ", context, ") ---")
	if player_data and player_data.base_stats:
		# ... (기존 디버그 코드 유지) ...
		pass
	
	if current_player_stats:
		# ... (기존 디버그 코드 유지) ...
		pass
	print("DEBUG: PlayerManager: ------------------------------------------")

func _ready():
	if player_data == null:
		# 리소스 로드는 DataManager가 생기면 거기로 옮길 예정
		player_data = (load("res://resources/characters/player/Novice.tres") as CharacterData).duplicate(true)
	
	_print_stats_debug_info("_ready")

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

# [신규] 장비로 인한 스탯 수정자 저장 (slot_key -> Array[MyStatModifier])
var equipment_modifiers: Dictionary = {}

# [신규] 방어구 유형별 장착 개수
var armor_counts: Dictionary = {
	"cloth": 0,
	"light": 0,
	"heavy": 0
}

# [신규] 아이템 장착 함수
func equip_item(slot_key: String, item_data: Dictionary):
	if equipment.has(slot_key):
		# 기존 장비가 있다면 먼저 해제
		if equipment[slot_key]:
			unequip_item(slot_key)
			
		equipment[slot_key] = item_data
		_apply_equipment_stats(slot_key, item_data, true)
		_update_armor_counts() # 방어구 카운트 갱신
		print("DEBUG: ", slot_key, " 부위에 ", item_data.get("name", "아이템"), " 장착 완료.")

# [신규] 아이템 해제 함수
func unequip_item(slot_key: String):
	if equipment.has(slot_key) and equipment[slot_key]:
		var item_data = equipment[slot_key]
		_apply_equipment_stats(slot_key, item_data, false)
		equipment[slot_key] = null
		_update_armor_counts() # 방어구 카운트 갱신
		print("DEBUG: ", slot_key, " 부위 장비 해제 완료.")

# [신규] 방어구 유형 카운트 갱신
func _update_armor_counts():
	armor_counts = {"cloth": 0, "light": 0, "heavy": 0}
	for slot in equipment.keys():
		var item = equipment[slot]
		if item and item.has("armor_type"):
			var type = item["armor_type"]
			if armor_counts.has(type):
				armor_counts[type] += 1
	
	# 플레이어 노드가 있다면 즉시 동기화
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and is_instance_valid(game_manager.player_node):
		game_manager.player_node.sync_armor_profile(armor_counts)

# [신규] 장비 스탯 반영 로직
func _apply_equipment_stats(slot_key: String, item_data: Dictionary, is_equipping: bool):
	if not current_player_stats: return
	
	if is_equipping:
		var modifiers: Array[MyStatModifier] = []
		var item_stats = item_data.get("stats", {})
		
		# 아이템 데이터의 stats 딕셔너리를 순회하며 수정자 생성
		for stat_key in item_stats.keys():
			var value = item_stats[stat_key]
			var target_key = _map_item_stat_to_player_stat(stat_key)
			
			if target_key != "":
				var stat = current_player_stats.get_stat(target_key)
				if stat:
					var modifier = MyIntStatModifier.new()
					modifier.value = value
					modifier.operation = MyStatModifier.Operation.ADD
					modifier.target_stat_key = target_key
					stat.add_modifier(modifier)
					modifiers.append(modifier)
		
		equipment_modifiers[slot_key] = modifiers
	else:
		# 기존에 적용된 수정자들을 제거
		if equipment_modifiers.has(slot_key):
			for modifier in equipment_modifiers[slot_key]:
				var stat = current_player_stats.get_stat(modifier.target_stat_key)
				if stat:
					stat.remove_modifier(modifier)
			equipment_modifiers.erase(slot_key)

# 아이템 데이터의 스탯 키를 시스템 스탯 키로 매핑
func _map_item_stat_to_player_stat(item_stat_key: String) -> String:
	match item_stat_key.to_lower():
		"atk", "attack": return "attack_power"
		"def", "defense": return "defense"
		"hp", "health": return "health"
		"spd", "speed": return "attack_speed"
		"mp", "mana": return "current_mp"
		"luck": return "luck"
		"int", "intelligence": return "intelligence"
		"agi", "agility": return "agility"
	return ""
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
	
	# [신규] 플레이어 고유 ID 할당 (비동기 멀티플레이 대응)
	if player_data.uid == "":
		player_data.uid = PlatformManager.generate_uuid()
		print("PlayerManager: New Player UID generated: ", player_data.uid)
	
	# [수정] current_player_stats가 이미 있다면(씬 재로드 등) 초기화하지 않음
	if current_player_stats == null:
		current_player_stats = player_data.base_stats.duplicate(true)
		print("PlayerManager: 초기 스탯 생성 완료.")
	
	_print_stats_debug_info("_ready")

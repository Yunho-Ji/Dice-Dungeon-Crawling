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

# [신규] 인벤토리(가방) 데이터 백업 (InventoryScreen 파괴 대비)
# 형식: Array[Dictionary] (GridInventory.item_states와 동일)
var inventory_data: Array = []

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

# [신규] 아이템 장착 가능 여부 확인 (스탯 요구사항 등)
func can_equip_item(item_data: Dictionary) -> bool:
	if not item_data.has("requirements"):
		return true # 요구사항이 없으면 누구나 장착 가능
		
	var reqs = item_data["requirements"]
	
	# 1. 스탯 요구사항 체크
	for stat_key in reqs.keys():
		if stat_key == "class": continue # 클래스 제한은 추후 구현

		var required_value = reqs[stat_key]
		var normalized_key = StatManager.normalize_stat_key(stat_key)
		
		# 현재 플레이어 스탯 (기본값 + 현재 장비 보정 포함)
		var current_stat = current_player_stats.get_stat(normalized_key)
		
		if current_stat and current_stat.computed_value < required_value:
			print("장착 불가: ", normalized_key, " 부족 (필요: ", required_value, ", 현재: ", current_stat.computed_value, ")")
			# UI에 경고를 띄우기 위해 SignalBus 등을 사용할 수 있음
			return false
			
	return true

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

# [신규] 장비 스탯 반영 로직 (리팩토링 완료: StatInterpreter 위임)
func _apply_equipment_stats(slot_key: String, item_data: Dictionary, is_equipping: bool):
	if not current_player_stats: return
	
	if is_equipping:
		var item_stats = item_data.get("stats", {})
		print("DEBUG: Applying stats via StatInterpreter for item: ", item_data.get("id"))
		
		# 1. StatInterpreter를 통해 효과 객체 생성 (레거시 JSON -> Effect 변환)
		var new_effects = StatInterpreter.parse_stats(item_stats)
		
		# 2. 효과 적용
		for effect in new_effects:
			# [수정] effect.apply(player_data) 호출 제거 (타입 불일치 해결)
			# StatInterpreter가 반환한 Effect 객체는 데이터 홀더로 사용하고,
			# PlayerManager가 직접 current_player_stats에 적용합니다.
			
			if effect is StatModifierEffect:
				var stat = current_player_stats.get_stat(effect.stat_key)
				if stat:
					var mod = MyIntStatModifier.new() # MyStatModifier 대신 MyIntStatModifier 사용 권장 (구체 클래스)
					mod.value = int(effect.value) # float -> int 명시적 변환
					mod.target_stat_key = effect.stat_key
					mod.operation = MyStatModifier.Operation.ADD if not effect.is_multiplier else MyStatModifier.Operation.MULTIPLY
					stat.add_modifier(mod)
					
					# 나중에 해제할 수 있도록 추적
					if not equipment_modifiers.has(slot_key):
						equipment_modifiers[slot_key] = []
					equipment_modifiers[slot_key].append(mod)
					
					print("DEBUG: Effect Applied: ", effect.get_description())
		
	else:
		# 장비 해제 시: 저장해둔 Modifier들을 제거
		if equipment_modifiers.has(slot_key):
			for modifier in equipment_modifiers[slot_key]:
				var stat = current_player_stats.get_stat(modifier.target_stat_key)
				if stat:
					stat.remove_modifier(modifier)
			equipment_modifiers.erase(slot_key)
			print("DEBUG: Effects removed for slot: ", slot_key)

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

# [신규] 게임 세션 시작 시 호출 (SceneManager 등에서 호출)
func initialize_session():
	if current_player_stats == null and player_data:
		current_player_stats = player_data.base_stats.duplicate(true)
	
	# 기본 장비가 하나도 없다면 초기 장비 지급
	var has_equipment = false
	for slot in equipment.values():
		if slot != null:
			has_equipment = true
			break
			
	if not has_equipment:
		_equip_starting_gear()

func _equip_starting_gear():
	# 기본 지급 아이템 목록 (ID, 슬롯) - 테스트용 데이터로 교체
	var starter_items = [
		{"id": "test_grimoire_epic", "slot": "right_hand"},
		{"id": "test_cloth_top_rare", "slot": "top"},
		{"id": "test_leather_shoes_common", "slot": "shoes"}
	]
	
	print("PlayerManager: 기본 장비 지급 시작... (Apeloot Items Count: ", Apeloot.items.size(), ")")
	for item in starter_items:
		var item_id = item["id"]
		var slot_key = item["slot"]
		
		# Apeloot 데이터베이스에서 아이템 정보 가져오기
		if Apeloot.items.has(item_id):
			var item_data = Apeloot.items[item_id].duplicate()
			item_data["id"] = item_id # ID 주입
			print("DEBUG: Equipping starter item: ", item_id, " Stats: ", item_data.get("stats", {}))
			
			# 장착 실행 (요구사항 무시하고 강제 장착)
			equip_item(slot_key, item_data)
		else:
			printerr("PlayerManager: 기본 장비 아이템을 찾을 수 없습니다 - ", item_id)

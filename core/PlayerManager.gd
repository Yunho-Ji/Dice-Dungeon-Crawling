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

# [신규] 장비로 인한 활성 효과 객체 저장 (slot_key -> Array[ItemEffect])
var equipment_effects: Dictionary = {}

# [신규] 인벤토리(가방) 데이터 백업 (InventoryScreen 파괴 대비)
# 형식: Array[Dictionary] (GridInventory.item_states와 동일)
var inventory_data: Array = []

# [신규] 인벤토리 UI 부재 시 획득한 아이템 대기열
var pending_items: Array[String] = []

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

# [신규] 장비 스탯 반영 로직 (리팩토링 완료: StatInterpreter 위임 & 통합 Effect 처리)
func _apply_equipment_stats(slot_key: String, item_data: Dictionary, is_equipping: bool):
	if not current_player_stats: return
	
	var player_node = null
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		player_node = game_manager.player_node

	if is_equipping:
		var item_stats = item_data.get("stats", {})
		print("DEBUG: Parsing stats for item: ", item_data.get("id"))
		
		# 1. StatInterpreter를 통해 효과 객체 생성
		var new_effects = StatInterpreter.parse_stats(item_stats)
		
		# 효과 리스트 초기화
		if not equipment_effects.has(slot_key):
			equipment_effects[slot_key] = []
			
		# 2. 효과 적용 및 저장
		for effect in new_effects:
			# 저장 (해제 시 사용)
			equipment_effects[slot_key].append(effect)
			
			if effect is StatModifierEffect:
				# 스탯 수정은 PlayerManager의 데이터(current_player_stats)에 직접 적용
				# (PlayerNode가 없어도 스탯은 유지되어야 함)
				var stat = current_player_stats.get_stat(effect.stat_key)
				if stat:
					var mod = MyStatModifier.new() # 타입 추론에 맡김
					mod.value = effect.value
					mod.target_stat_key = effect.stat_key
					mod.operation = MyStatModifier.Operation.ADD if not effect.is_multiplier else MyStatModifier.Operation.MULTIPLY
					stat.add_modifier(mod)
					
					# StatModifierEffect 내부에 참조 저장 (나중에 필요할까 싶어서)
					effect._applied_modifier = mod 
					print("DEBUG: Stat Effect Applied: ", effect.get_description())
					
			elif effect is ActionTriggerEffect:
				# 트리거 효과는 실제 캐릭터 노드가 있어야 작동
				if player_node and is_instance_valid(player_node):
					effect.apply(player_node)
					print("DEBUG: Trigger Effect Applied: ", effect.get_description())
				else:
					print("DEBUG: Trigger Effect Pending (No Player Node): ", effect.get_description())
					# TODO: 씬 변경 시(플레이어 노드 생성 시) 재적용 로직 필요
		
	else:
		# 장비 해제 시: 저장해둔 Effect들을 제거
		if equipment_effects.has(slot_key):
			for effect in equipment_effects[slot_key]:
				if effect is StatModifierEffect:
					if effect._applied_modifier:
						var stat = current_player_stats.get_stat(effect.stat_key)
						if stat:
							stat.remove_modifier(effect._applied_modifier)
							
				elif effect is ActionTriggerEffect:
					if player_node and is_instance_valid(player_node):
						effect.remove(player_node)
						
			equipment_effects.erase(slot_key)
			print("DEBUG: Effects removed for slot: ", slot_key)

# [신규] 씬 변경 등으로 플레이어 노드가 새로 생성되었을 때 효과 재적용
func reapply_equipment_effects(player_node: Character):
	if not player_node: return
	
	print("DEBUG: Reapplying equipment effects to new player node...")
	
	# 1. 방어구 정보 동기화
	player_node.sync_armor_profile(armor_counts)
	
	# 2. 트리거 효과 재연결
	for slot_key in equipment_effects.keys():
		for effect in equipment_effects[slot_key]:
			if effect is ActionTriggerEffect:
				# 이전 노드에서 제거 (혹시 모르니 안전장치)
				effect.remove(player_node) 
				# 새 노드에 적용
				effect.apply(player_node)
				print("DEBUG: Reapplied trigger effect: ", effect.get_description())

# [신규] 인벤토리 UI 부재 시 아이템을 대기열에 추가
func add_pending_item(item_id: String):
	pending_items.append(item_id)
	print("PlayerManager: 아이템이 대기열에 추가됨 (UI 로드 시 획득) - ", item_id)

# [신규] 대기 중인 아이템 목록을 반환하고 대기열 비우기
func consume_pending_items() -> Array[String]:
	var items = pending_items.duplicate()
	pending_items.clear()
	return items

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

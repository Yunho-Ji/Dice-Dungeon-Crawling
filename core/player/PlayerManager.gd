# PlayerManager.gd
extends Node

@export var player_data: Resource # CharacterData -> Resource
var current_player_stats: Resource # MyCharacterStats -> Resource

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

# [신규] 장비로 인한 활성 효과 객체 저장
var equipment_effects: Dictionary = {}

# [신규] 커스텀 인벤토리 데이터 (Model)
var inventory_data: Resource # InventoryData -> Resource

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
		if equipment[slot_key]:
			unequip_item(slot_key)
			
		equipment[slot_key] = item_data
		_apply_equipment_stats(slot_key, item_data, true)
		_update_armor_counts()
		print("DEBUG: ", slot_key, " 부위에 ", item_data.get("name", "아이템"), " 장착 완료.")

# [신규] 아이템 해제 함수
func unequip_item(slot_key: String):
	if equipment.has(slot_key) and equipment[slot_key]:
		var item_data = equipment[slot_key]
		var item_id = item_data.get("id", "")
		
		_apply_equipment_stats(slot_key, item_data, false)
		
		equipment[slot_key] = null
		_update_armor_counts()
		
		if item_id != "":
			var inv_mgr = get_node_or_null("/root/InventoryManager")
			if inv_mgr and inv_mgr.has_method("try_add_item"):
				inv_mgr.try_add_item(item_id)

# [신규] 아이템 장착 가능 여부 확인
func can_equip_item(item_data: Dictionary) -> bool:
	if not item_data.has("requirements"):
		return true
		
	var reqs = item_data["requirements"]
	for stat_key in reqs.keys():
		if stat_key == "class": continue
		var required_value = reqs[stat_key]
		
		var stats = current_player_stats
		if stats and stats.has_method("get_stat"):
			var current_stat = stats.get_stat(stat_key)
			if current_stat and current_stat.get("computed_value") < required_value:
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
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and is_instance_valid(gm.get("player_node")):
		var player_node = gm.get("player_node")
		if player_node.has_method("sync_armor_profile"):
			player_node.sync_armor_profile(armor_counts)

# [신규] 장비 스탯 반영 로직
func _apply_equipment_stats(slot_key: String, item_data: Dictionary, is_equipping: bool):
	if not current_player_stats: return
	
	var player_node = null
	var gm = get_node_or_null("/root/GameManager")
	if gm: player_node = gm.get("player_node")

	if is_equipping:
		var item_stats = item_data.get("stats", {})
		var si = get_node_or_null("/root/StatInterpreter") # StatInterpreter를 노드로 사용하거나 정적 호출
		var new_effects = []
		if si and si.has_method("parse_stats"):
			new_effects = si.parse_stats(item_stats)
		
		if not equipment_effects.has(slot_key):
			equipment_effects[slot_key] = []
			
		for effect in new_effects:
			equipment_effects[slot_key].append(effect)
			
			if effect.get_script().get_global_name() == "StatModifierEffect":
				var stat = current_player_stats.get_stat(effect.get("stat_key"))
				if stat:
					# MyStatModifier 인스턴스 생성 및 설정 (동적)
					var mod_script = load("res://resources/stats/MyStatModifier.gd")
					var mod = mod_script.new()
					mod.set("value", effect.get("value"))
					mod.set("target_stat_key", effect.get("stat_key"))
					mod.set("operation", 0 if not effect.get("is_multiplier") else 1)
					stat.call("add_modifier", mod)
					effect.set("_applied_modifier", mod)
				elif effect.get("stat_key") == "attack_range" or effect.get("stat_key") == "move_range":
					if player_node and is_instance_valid(player_node):
						var val = player_node.get(effect.get("stat_key"))
						player_node.set(effect.get("stat_key"), val + int(effect.get("value")))
					
			elif effect.get_script().get_global_name() == "ActionTriggerEffect":
				if player_node and is_instance_valid(player_node):
					effect.call("apply", player_node)
		
	else:
		if equipment_effects.has(slot_key):
			for effect in equipment_effects[slot_key]:
				if effect.get_script().get_global_name() == "StatModifierEffect":
					if effect.get("_applied_modifier"):
						var stat = current_player_stats.get_stat(effect.get("stat_key"))
						if stat:
							stat.call("remove_modifier", effect.get("_applied_modifier"))
						elif effect.get("stat_key") == "attack_range" or effect.get("stat_key") == "move_range":
							if player_node and is_instance_valid(player_node):
								var val = player_node.get(effect.get("stat_key"))
								player_node.set(effect.get("stat_key"), val - int(effect.get("value")))
							
				elif effect.get_script().get_global_name() == "ActionTriggerEffect":
					if player_node and is_instance_valid(player_node):
						effect.call("remove", player_node)
						
			equipment_effects.erase(slot_key)

func reapply_equipment_effects(player_node_ref: Node):
	if not player_node_ref: return
	if player_node_ref.has_method("sync_armor_profile"):
		player_node_ref.sync_armor_profile(armor_counts)
	for slot_key in equipment_effects.keys():
		for effect in equipment_effects[slot_key]:
			if effect.get_script().get_global_name() == "ActionTriggerEffect":
				effect.call("remove", player_node_ref) 
				effect.call("apply", player_node_ref)

func add_pending_item(item_id: String):
	pending_items.append(item_id)

func consume_pending_items() -> Array[String]:
	var items = pending_items.duplicate()
	pending_items.clear()
	return items

func _ready():
	var inv_script = load("res://core/inventory/InventoryData.gd")
	if inv_script:
		inventory_data = inv_script.new(Vector2i(10, 5))
		
	if player_data == null:
		player_data = load("res://resources/characters/player/Novice.tres")
	
	if player_data and player_data.get("uid") == "":
		var plat_mgr = get_node_or_null("/root/PlatformManager")
		if plat_mgr: player_data.set("uid", plat_mgr.call("generate_uuid"))
	
	if current_player_stats == null and player_data:
		current_player_stats = player_data.get("base_stats").duplicate(true)
	
func initialize_session():
	if current_player_stats == null and player_data:
		current_player_stats = player_data.get("base_stats").duplicate(true)
	
	var has_equipment = false
	for slot in equipment.values():
		if slot != null:
			has_equipment = true
			break
			
	if not has_equipment:
		_equip_starting_gear()

func _equip_starting_gear():
	var starter_items = []
	var p_class_name = "Novice"
	
	if player_data:
		p_class_name = player_data.get("character_name")
		
	if p_class_name == "Novice":
		starter_items = [
			{"id": "basic_sword", "slot": "right_hand"},
			{"id": "basic_cloth_armor", "slot": "top"},
			{"id": "basic_leather_boots", "slot": "shoes"}
		]
	elif p_class_name == "Archer":
		starter_items = [
			{"id": "basic_bow", "slot": "right_hand"},
			{"id": "basic_cloth_armor", "slot": "top"},
			{"id": "basic_leather_boots", "slot": "shoes"}
		]
	
	var dm = get_node_or_null("/root/DataManager")
	if not dm: return

	for item in starter_items:
		var item_id = item["id"]
		var slot_key = item["slot"]
		var item_data = dm.call("get_item", item_id)
		if not item_data.is_empty():
			item_data["id"] = item_id
			equip_item(slot_key, item_data)

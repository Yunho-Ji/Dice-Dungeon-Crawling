extends Node

# SaveManager
# 역할: 게임 데이터의 직렬화(Serialization), 파일 입출력, Steam Cloud 대응을 위한 파일 구조 관리를 담당합니다.

const SAVE_DIR = "user://saves/"
const SAVE_PATH_FORMAT = "user://saves/save_slot_%d.json"
const GHOST_DIR = "user://ghosts/"
const MY_GHOST_PATH = "user://ghosts/my_ghost.json"

var is_in_inn: bool = false # 여관에 있는지 여부

# 여관(Inn)에서 호출할 저장 함수
func save_game_at_inn(slot_id: int = 1) -> bool:
	if not is_in_inn:
		print("SaveManager: 여관이 아닌 곳에서는 저장할 수 없습니다.")
		return false
	
	return _execute_save(slot_id)

func _execute_save(slot_id: int) -> bool:
	var save_data = {
		"meta": {
			"version": "1.1",
			"timestamp": Time.get_datetime_dict_from_system(),
			"steam_id": PlatformManager.get_steam_id(),
			"username": PlatformManager.get_username(),
			"platform": PlatformManager.get_platform_name()
		},
		"economy": EconomyManager.get_gold(),
		"player": {
			"uid": PlayerManager.player_data.uid if PlayerManager.player_data else "",
			"stats": _get_player_stats_data(),
			"equipment": PlayerManager.equipment,
			"statuses": [] 
		},
		"inventory": _get_inventory_data(),
		"dice": DiceManager.get_player_dice_pool(),
		"dungeon_progress": {} 
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	
	# 1. 로컬 저장
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		
	var file_path = SAVE_PATH_FORMAT % slot_id
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("SaveManager: 로컬 세이브 완료. 슬롯: ", slot_id)
		
		# 2. Steam Cloud 동기화 (MVP)
		if PlatformManager.is_cloud_enabled():
			var cloud_file_name = "save_slot_%d.json" % slot_id
			PlatformManager.cloud_save_file(cloud_file_name, json_string)
		
		# 3. 고스트 데이터 생성 및 저장 (비동기 MP 기초)
		_save_ghost_data(save_data)
		
		return true
	
	return false

## 비동기 상호작용을 위한 고스트 데이터 추출 및 저장
func _save_ghost_data(full_save_data: Dictionary):
	var ghost_data = {
		"uid": full_save_data.player.uid,
		"username": full_save_data.meta.username,
		"timestamp": full_save_data.meta.timestamp,
		"stats": full_save_data.player.stats,
		"equipment": full_save_data.player.equipment,
		"dice_summary": {
			"total_count": full_save_data.dice.size(),
			"max_dice": full_save_data.dice.max() if full_save_data.dice.size() > 0 else 0
		}
	}
	
	if not DirAccess.dir_exists_absolute(GHOST_DIR):
		DirAccess.make_dir_recursive_absolute(GHOST_DIR)
		
	var ghost_json = JSON.stringify(ghost_data, "\t")
	var file = FileAccess.open(MY_GHOST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(ghost_json)
		file.close()
		print("SaveManager: 고스트 데이터 내보내기 완료: ", MY_GHOST_PATH)

## 타 유저의 고스트 데이터 로드 (비동기 상호작용용)
func load_ghost_data(ghost_path: String) -> Dictionary:
	if not FileAccess.file_exists(ghost_path):
		return {}
		
	var file = FileAccess.open(ghost_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		return json.data
	return {}

func load_game(slot_id: int = 1) -> bool:
	var path = SAVE_PATH_FORMAT % slot_id
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return false
		
	_apply_load_data(json.data)
	return true

func _get_player_stats_data() -> Dictionary:
	var stats_data = {}
	if PlayerManager.current_player_stats:
		for key in PlayerManager.current_player_stats.get_all_stat_keys():
			var stat = PlayerManager.current_player_stats.get_stat(key)
			if stat:
				stats_data[key] = {
					"base": stat.base_value,
					"current": stat.current_value
				}
	return stats_data

func _get_inventory_data() -> Array:
	var items_data = []
	var inventory = Apeloot.inventory_refs.get("player_inventory")
	if inventory:
		for item in inventory.items:
			items_data.append({
				"id": item.id,
				"instance_id": item.instance_id,
				"previous_center_slot": item.previous_center_slot,
				"orientation": item.orientation,
				"stack_count": item.stack_count,
				"rarity": item.rarity,
				"stats": item.stats,
				"price": item.price
			})
	return items_data

func _apply_load_data(data: Dictionary):
	if data.has("economy"):
		EconomyManager.set_gold(data.economy)
	
	if data.has("player") and PlayerManager.current_player_stats:
		if data.player.has("uid") and PlayerManager.player_data:
			PlayerManager.player_data.uid = data.player.uid
			
		if data.player.has("stats"):
			var stats_data = data.player.stats
			for key in stats_data.keys():
				var stat = PlayerManager.current_player_stats.get_stat(key)
				if stat:
					stat.base_value = stats_data[key].get("base", stat.base_value)
					stat.current_value = stats_data[key].get("current", stat.current_value)
	
	var inventory = Apeloot.inventory_refs.get("player_inventory")
	if inventory and data.has("inventory"):
		inventory.initialize_inventory(data.inventory)

	if data.has("dice"):
		DiceManager.player_dice_pool = data.dice
		DiceManager.player_dice_pool.sort()
		
	print("SaveManager: 모든 데이터 로드 완료.")

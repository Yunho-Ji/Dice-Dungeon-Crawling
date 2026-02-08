extends Node

# SaveManager
# 역할: 게임 데이터의 직렬화(Serialization), 파일 입출력, Steam Cloud 대응을 위한 파일 구조 관리를 담당합니다.
# 모든 매니저(Inventory, Map, Player 등)를 순회하며 데이터를 수집하여 저장합니다.

const SAVE_DIR = "user://saves/"

func save_game(slot_id: int):
	var data = {}
	# 각 매니저에게 데이터 요청 (추후 구현)
	# data["player"] = PlayerManager.get_save_data()
	# data["inventory"] = InventoryManager.get_save_data()
	
	_write_to_file(slot_id, data)

func _write_to_file(slot_id: int, data: Dictionary):
	# 파일 쓰기 로직
	pass

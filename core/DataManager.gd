extends Node

# DataManager
# 역할: 게임 내 정적 데이터(아이템 DB, 몬스터 정보, 스킬 데이터)를 로드하고 제공합니다.
# 리소스 폴더를 스캔하여 메모리에 캐싱하는 역할을 합니다.

var item_db: Dictionary = {}

func _ready():
	_load_item_database()

func _load_item_database():
	# res://resources/items 폴더 스캔 로직 (추후 구현)
	pass

func get_item_info(id: String):
	return item_db.get(id)

extends Node

@export var player_data: CharacterData # 플레이어의 캐릭터 데이터 리소스
var current_player_stats: MyCharacterStats # 전투 간 플레이어의 현재 스탯을 저장

# [Refactor Note] 골드 관리는 EconomyManager로 이관되었습니다.
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

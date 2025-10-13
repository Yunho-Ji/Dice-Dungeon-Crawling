class_name DiceManager
extends Node

var player_dice_pool: Array = [] # 플레이어가 획득한 주사위의 면체 수를 저장할 풀

func _ready():
	pass

# 주사위 풀에 주사위(면체 수)를 추가합니다.
func add_dice_to_pool(dice_sides: int):
	player_dice_pool.append(dice_sides)
	player_dice_pool.sort() # 항상 오름차순으로 정렬하여 가장 낮은 주사위를 쉽게 찾을 수 있도록 합니다.
	print("DiceManager: 주사위 추가! 현재 주사위 풀 (면체 수): ", player_dice_pool)

# 가장 낮은 면체 수의 주사위를 새로운 주사위로 교체하고, 교체된 주사위의 면 수를 반환합니다.
func replace_lowest_dice(new_sides: int) -> int:
	if player_dice_pool.is_empty():
		print("오류: 주사위 풀이 비어있어 교체할 주사위가 없습니다.")
		return -1 # 오류 값 반환

	var lowest_dice_index = 0 # 정렬되어 있으므로 첫 번째 요소가 가장 낮습니다.
	var old_sides = player_dice_pool[lowest_dice_index]

	player_dice_pool[lowest_dice_index] = new_sides
	player_dice_pool.sort() # 교체 후 다시 정렬

	print("DiceManager: D", old_sides, " 주사위를 D", new_sides, " 주사위로 교체했습니다. 현재 주사위 풀: ", player_dice_pool)
	return old_sides # 교체된 주사위의 면 수를 반환

# 갬블 실패 시, 마지막으로 교체된 주사위를 원래대로 되돌립니다.
func revert_last_replacement(newly_added_sides: int, original_sides: int):
	# 새로 추가된 주사위(newly_added_sides)를 찾아서 제거합니다.
	var index_to_remove = player_dice_pool.find(newly_added_sides)
	if index_to_remove != -1:
		player_dice_pool.remove_at(index_to_remove)
		# 원래 주사위(original_sides)를 다시 추가합니다.
		player_dice_pool.append(original_sides)
		player_dice_pool.sort()
		print("DiceManager: 갬블 실패! D", newly_added_sides, " 주사위가 파괴되고 D", original_sides, " 주사위로 되돌아갑니다. 현재 풀: ", player_dice_pool)
	else:
		print("오류: 되돌릴 주사위(D", newly_added_sides, ")를 풀에서 찾을 수 없습니다.")

# 전리품 라운드에서 획득할 새로운 주사위의 종류(면체 수)를 결정합니다.
func generate_new_dice_type(current_battle_count: int) -> int:
	var max_sides = 0
	if current_battle_count == 4:
		max_sides = 8
	elif current_battle_count == 7:
		max_sides = 12
	else:
		print("경고: 현재 전투 횟수(", current_battle_count, ")에 해당하는 전리품 주사위가 정의되지 않았습니다.")
		return -1 # 오류

	# 최소 D2 주사위에서 최대 면체 수 사이의 주사위를 랜덤하게 결정
	var new_dice_sides = randi_range(2, max_sides)
	print("DiceManager: 새로운 주사위 타입 결정 - D", new_dice_sides)
	return new_dice_sides

func get_player_dice_pool() -> Array:
	return player_dice_pool

func remove_die(sides_to_remove: int):
	var index_to_remove = player_dice_pool.find(sides_to_remove)
	if index_to_remove != -1:
		player_dice_pool.remove_at(index_to_remove)
		print("DiceManager: 갬블 실패! D", sides_to_remove, " 주사위를 잃었습니다. 현재 풀: ", player_dice_pool)
	else:
		print("오류: 제거할 주사위(D", sides_to_remove, ")를 풀에서 찾을 수 없습니다.")



# 주사위 풀에 있는 모든 주사위를 굴려 결과를 반환합니다. (풀에서 제거하지 않음)
func roll_player_dice() -> Array:
	var rolled_results = []
	print("DiceManager: 주사위 굴림 시작. 현재 주사위 풀 (면체 수): ", player_dice_pool)
	for dice_sides in player_dice_pool:
		var roll = randi_range(1, dice_sides)
		rolled_results.append(roll)
	
	rolled_results.sort_custom(func(a, b): return a > b) # 내림차순 정렬
	print("DiceManager: 굴려진 주사위 결과 (눈금): ", rolled_results)
	return rolled_results
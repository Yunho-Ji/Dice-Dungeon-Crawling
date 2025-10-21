extends Node

signal dice_rolled(rolled_values: Array)

var player_dice_pool: Array = []
var can_roll_new_dice: bool = false

func _ready():
	pass

func can_roll() -> bool:
	return can_roll_new_dice

func enable_roll():
	can_roll_new_dice = true

func add_dice_to_pool(dice_sides: int):
	player_dice_pool.append(dice_sides)
	player_dice_pool.sort()
	print("DiceManager: 주사위 추가! 현재 주사위 풀 (면체 수): ", player_dice_pool)

func replace_lowest_dice(new_sides: int) -> int:
	if player_dice_pool.is_empty():
		print("오류: 주사위 풀이 비어있어 교체할 주사위가 없습니다.")
		return -1

	var lowest_dice_index = 0
	var old_sides = player_dice_pool[lowest_dice_index]

	player_dice_pool[lowest_dice_index] = new_sides
	player_dice_pool.sort()

	print("DiceManager: D", old_sides, " 주사위를 D", new_sides, " 주사위로 교체했습니다. 현재 주사위 풀: ", player_dice_pool)
	return old_sides

func revert_last_replacement(newly_added_sides: int, original_sides: int):
	var index_to_remove = player_dice_pool.find(newly_added_sides)
	if index_to_remove != -1:
		player_dice_pool.remove_at(index_to_remove)
		player_dice_pool.append(original_sides)
		player_dice_pool.sort()
		print("DiceManager: 갬블 실패! D", newly_added_sides, " 주사위가 파괴되고 D", original_sides, " 주사위로 되돌아갑니다. 현재 풀: ", player_dice_pool)
	else:
		print("오류: 되돌릴 주사위(D", newly_added_sides, ")를 풀에서 찾을 수 없습니다.")

func generate_new_dice_type(current_battle_count: int) -> int:
	var max_sides = 0
	if current_battle_count == 4:
		max_sides = 8
	elif current_battle_count == 7:
		max_sides = 12
	else:
		print("경고: 현재 전투 횟수(", current_battle_count, ")에 해당하는 전리품 주사위가 정의되지 않았습니다.")
		return -1

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

func roll_player_dice():
	if not can_roll_new_dice:
		print("DiceManager: 지금은 주사위를 굴릴 수 없습니다.")
		return

	can_roll_new_dice = false
	var rolled_results = []
	print("DiceManager: 주사위 굴림 시작. 현재 주사위 풀 (면체 수): ", player_dice_pool)
	for dice_sides in player_dice_pool:
		var roll = randi_range(1, dice_sides)
		rolled_results.append(roll)
	
	rolled_results.sort_custom(func(a, b): return a > b)
	print("DiceManager: 굴려진 주사위 결과 (눈금): ", rolled_results)
	emit_signal("dice_rolled", rolled_results)
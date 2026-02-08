extends Node

signal dice_rolled(rolled_values: Array)

var player_dice_pool: Array = []
var pending_rewards: Array = [] 
var can_roll_new_dice: bool = false
var needs_redistribution: bool = false # [신규] 재분배 기회 부여 여부 플래그
var last_roll_results: Array = [] 

# [신규] 모든 주사위의 사용 상태 초기화 (재분배 모드 진입 시 호출)
func reset_all_dice_usage():
	for res in last_roll_results:
		res["is_used"] = false
	needs_redistribution = false # 초기화 수행 후 플래그 해제
	print("DiceManager: 모든 주사위 상태가 '미사용'으로 초기화되었습니다.")

# [개선] 주사위 사용 상태 업데이트
func mark_dice_as_used(sides: int, value: int, used: bool = true):
	for res in last_roll_results:
		if res.sides == sides and res.value == value and res.is_used != used:
			res.is_used = used
			return

const DICE_ASSETS = {
	4: "res://assets/sprites/assets/D&D Dice/d4.png",
	6: "res://assets/sprites/assets/D&D Dice/d6.png",
	8: "res://assets/sprites/assets/D&D Dice/d8.png",
	10: "res://assets/sprites/assets/D&D Dice/d10.png",
	12: "res://assets/sprites/assets/D&D Dice/d12.png",
	20: "res://assets/sprites/assets/D&D Dice/d20.png"
}

func add_pending_reward(dice_sides: int):
	pending_rewards.append(dice_sides)

func confirm_reward(reward_index: int):
	if reward_index < 0 or reward_index >= pending_rewards.size(): return
	var new_sides = pending_rewards[reward_index]
	if replace_lowest_dice(new_sides) != -1:
		pending_rewards.remove_at(reward_index)

func can_roll() -> bool:
	return can_roll_new_dice

func enable_roll():
	can_roll_new_dice = true
	needs_redistribution = true # [중요] 새로운 기회 획득 시 재분배 권한 활성화

func add_dice_to_pool(dice_sides: int):
	player_dice_pool.append(dice_sides)
	player_dice_pool.sort()

func replace_lowest_dice(new_sides: int) -> int:
	if player_dice_pool.is_empty(): return -1
	var old_sides = player_dice_pool[0]
	player_dice_pool[0] = new_sides
	player_dice_pool.sort()
	return old_sides

func get_player_dice_pool() -> Array:
	return player_dice_pool

func roll_player_dice():
	if not can_roll_new_dice: return
	can_roll_new_dice = false
	var rolled_results = []
	for dice_sides in player_dice_pool:
		var roll = randi_range(1, dice_sides)
		rolled_results.append(roll)
	rolled_results.sort_custom(func(a, b): return a > b)
	emit_signal("dice_rolled", rolled_results)

extends Node
class_name GameManager
signal game_started

var selected_player_type: String = "novice"

enum GamePhase {
	MAIN_MENU,
	CHARACTER_SELECT,
	PREPARE,
	ROLL_DICE_FOR_EXPEDITION,
	COMBAT,
	RESOLVE,
	CAMP,
	LOOT_OFFER,
	LOOT_GAMBLE_PROMPT,
	LOOT_RESOLUTION
}

var current_game_phase: GamePhase
var dice_rolled_for_this_round: bool = false
var is_post_loot_round: bool = false # 주사위를 굴려야 하는 전리품 획득 후 라운드인지 확인

# 전리품 획득 흐름을 위한 임시 변수
var _current_loot_dice_sides: int = 0
var _replaced_die_sides: int = 0

const BOSS_BATTLE_COUNT = 8
var battle_manager: Node
var player_node: Character
var enemy_node: Character
var dice_manager: DiceManager
var ui_manager: UIManager
var is_developer_mode: bool = false # 개발자 모드 토글

var current_battle_count: int = 0
var current_stage: int = 1

func _ready():
	pass

func _start_game_internal():
	# UIManager는 initialize_game_scene에서 설정됨

	# 초기 주사위 풀 설정
	for i in range(4):
		dice_manager.add_dice_to_pool(6)

	# 첫 전투 준비
	_start_dice_roll_phase()

func initialize_game_scene(player: Character, enemy: Character, battle_mgr: Node, dice_mgr: DiceManager, ui_mgr: UIManager):
	player_node = player
	enemy_node = enemy
	battle_manager = battle_mgr
	dice_manager = dice_mgr
	ui_manager = ui_mgr

	if ui_manager and ui_manager is UIManager:
		ui_manager.game_manager = self
		ui_manager.player_node = player_node
		player_node.ui_manager = ui_manager
		ui_manager.update_player_stats_ui(player_node)
	else:
		printerr("GameManager: UIManager 노드를 찾을 수 없거나 UIManager 타입이 아닙니다!")

	_start_game_internal()


# --- 주사위 굴림 및 전투 시작 핸들러 ---

func handle_roll_dice():
	var dice_rolls = dice_manager.roll_player_dice()
	if ui_manager:
		ui_manager.update_dice_labels(dice_rolls)
	dice_rolled_for_this_round = true

func handle_start_combat():
	if ui_manager:
		ui_manager.hide_all_ui()

	player_node.update_hp_label()
	enemy_node.update_hp_label()

	player_node.target = enemy_node
	enemy_node.target = player_node

	if battle_manager:
		battle_manager.start_battle(player_node, enemy_node)

# --- 전투 종료 및 다음 단계 핸들러 ---

func handle_battle_end(win: bool):
	if win:
		current_battle_count += 1

		if current_battle_count > BOSS_BATTLE_COUNT:
			current_battle_count = 0
			current_stage += 1

		player_node.current_hp = min(player_node.max_hp, player_node.current_hp + player_node.recovery_power)
		player_node.update_hp_label()

		if current_battle_count == 4 or current_battle_count == 7:
			current_game_phase = GamePhase.LOOT_OFFER
			_current_loot_dice_sides = dice_manager.generate_new_dice_type(current_battle_count)
			if _current_loot_dice_sides > 0:
				if ui_manager:
					ui_manager.show_loot_offer(_current_loot_dice_sides)
			else:
				_start_dice_roll_phase()
		else:
			current_game_phase = GamePhase.RESOLVE
			if ui_manager:
				ui_manager.update_result_label("승리!")
				ui_manager.show_next_battle_phase("다음 전투")
	else:
		if ui_manager:
			ui_manager.show_defeat_screen()

func handle_next_battle():
	_start_dice_roll_phase()

# --- 새로운 전리품/갬블 흐름 핸들러 ---

func handle_loot_offer_decline():
	is_post_loot_round = true
	_start_dice_roll_phase()

func handle_loot_offer_accept():
	_replaced_die_sides = dice_manager.replace_lowest_dice(_current_loot_dice_sides)
	
	current_game_phase = GamePhase.LOOT_GAMBLE_PROMPT
	if ui_manager:
		var message = str("D", _replaced_die_sides) + "를 버리고 D" + str(_current_loot_dice_sides) + "를 획득했습니다."
		ui_manager.show_gamble_prompt(message)

func handle_gamble_decline():
	is_post_loot_round = true
	_start_dice_roll_phase()

func handle_gamble_accept():
	# DEBUG: 갬블 확률 조정 (면체수에 반비례)
	# 최대 주사위 면체수 (DiceManager.gd의 generate_new_dice_type 참고)
	var max_possible_sides = 12 
	var base_chance = float(max_possible_sides - _current_loot_dice_sides + 1) / max_possible_sides
	var success = randf() < base_chance
	
	# 개발자 모드: 갬블 확률 100%
	if is_developer_mode:
		success = true
		print("GameManager: 개발자 모드 활성화 - 갬블 성공률 100%.")
	
	if success:
		dice_manager.add_dice_to_pool(_current_loot_dice_sides)
	else:
		dice_manager.revert_last_replacement(_current_loot_dice_sides, _replaced_die_sides)
		
	current_game_phase = GamePhase.LOOT_RESOLUTION
	if ui_manager:
		ui_manager.show_gamble_result(success, _current_loot_dice_sides)

# 갬블 결과 확인 후 '계속' 버튼 클릭 시 호출
func handle_gamble_result_continue():
	is_post_loot_round = true
	_start_dice_roll_phase()

# --- 공통 헬퍼 함수 ---

func _start_dice_roll_phase(setup_new_enemy: bool = true):
	if setup_new_enemy:
		enemy_node.is_boss = (current_battle_count == BOSS_BATTLE_COUNT)
		enemy_node.set_level(current_stage, current_battle_count)
		enemy_node.position = Vector2(800, 300)
		
		if player_node.has_method("reset_for_next_battle"):
			player_node.reset_for_next_battle()
		if enemy_node.has_method("reset_for_next_battle"):
			enemy_node.reset_for_next_battle()

	if ui_manager:
		ui_manager.reset_dice_and_slots()
		ui_manager.update_stage_info(current_stage, current_battle_count)

	var is_first_battle = (current_stage == 1 and current_battle_count == 0)
	
	if is_first_battle or is_post_loot_round:
		is_post_loot_round = false
		current_game_phase = GamePhase.ROLL_DICE_FOR_EXPEDITION
		dice_rolled_for_this_round = false
		if ui_manager:
			ui_manager.show_roll_dice_phase()
	else:
		current_game_phase = GamePhase.COMBAT
		if ui_manager:
			ui_manager.show_pre_combat_phase()

func handle_retry():
	print("GameManager: 재도전. 상태를 초기화하고 씬을 다시 로드합니다.")
	current_stage = 1
	current_battle_count = 0
	if dice_manager and dice_manager.player_dice_pool:
		dice_manager.player_dice_pool.clear()
	get_tree().reload_current_scene()

func start_game_with_character(char_type: String):
	selected_player_type = char_type
	get_tree().change_scene_to_file("res://levels/Main.tscn")
	emit_signal("game_started")

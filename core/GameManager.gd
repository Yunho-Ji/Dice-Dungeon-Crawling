# GameManager.gd
# 역할: 게임의 전체적인 흐름과 상태를 관리하는 중앙 관리자입니다。
extends Node
class_name GameManager
# Force recompilation - Gemini (Attempt 2)

# =============================================================================
# 시그널 (Signals)
# =============================================================================
signal battle_started
signal battle_ended(win: bool)
signal dice_rolled_and_applied(rolled_values: Array)



enum GamePhase {
	MAIN_MENU, CHARACTER_SELECT, TOWN, PREPARE,
	DESTINY_DESIGN, # 운명 설계
	COMBAT, BATTLE_END, LOOT_OFFER
}
var current_game_phase: GamePhase

# --- 참조 변수 ---
var battle_manager: Node
var player_node: Character
var enemy_node: Character
var ui_manager: UIManager
var stage_info_hud: Control
var scene_manager: SceneManager
var player_manager: PlayerManager

# --- 게임 상태 변수 ---
var is_developer_mode: bool = false
var selected_dungeon_id: int = 0
var current_battle_count: int = 0
var current_stage: int = 1
const BOSS_BATTLE_COUNT = 8
var can_roll_new_dice: bool = false # 주사위 굴리기 가능 여부

# =============================================================================
# 초기화 함수 (Initialization)
# =============================================================================

func initialize_game_scene(player: Character, enemy: Character, battle_mgr: Node, ui_mgr: UIManager, stage_hud: Control, scene_mgr: SceneManager, player_mgr: PlayerManager):
	print("DEBUG: GameManager: initialize_game_scene called.") # New line
	print("GameManager: 게임 씬 초기화 중...")
	player_node = player
	enemy_node = enemy
	battle_manager = battle_mgr
	ui_manager = ui_mgr
	stage_info_hud = stage_hud
	scene_manager = scene_mgr
	player_manager = player_mgr
	print("DEBUG: GameManager: player_node valid: ", is_instance_valid(player_node)) # New line
	print("DEBUG: GameManager: enemy_node valid: ", is_instance_valid(enemy_node)) # New line

	if not is_instance_valid(ui_mgr):
		printerr("GameManager: UIManager가 유효하지 않습니다!")
		return

	# Connect damage signals
	if ui_manager and ui_manager.battle_hud:
		player_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(true)) # Player takes damage, so is_player_character is true for the popup
		enemy_node.damage_taken.connect(Callable(ui_manager.battle_hud, "_on_character_damage_taken").bind(false)) # Enemy takes damage, so is_player_character is false for the popup
	else:
		printerr("GameManager: UIManager or BattleHUD is not valid for connecting damage signals!")

	if get_node("/root/DiceManager").get_player_dice_pool().is_empty():
		for i in range(4):
			get_node("/root/DiceManager").add_dice_to_pool(6)

	# 현재 전투를 준비하고 '다음 전투' 버튼을 활성화합니다.
	prepare_current_battle()
	emit_signal("battle_ended", true)


# =============================================================================
# 게임 흐름 제어 함수 (Game Flow Control)
# =============================================================================

func prepare_current_battle():
	print("DEBUG: GameManager: prepare_current_battle called.") # New line
	print("GameManager: 다음 전투 준비")
	
	# 적 레벨 설정
	enemy_node.is_boss = (current_battle_count == BOSS_BATTLE_COUNT)
	enemy_node.set_level(current_stage, current_battle_count) # This should set enemy stats
	enemy_node.position = Vector2(800, 300)
	print("DEBUG: GameManager: Enemy stats after set_level: HP:", enemy_node.get_stat("max_hp"), ", ATK:", enemy_node.get_stat("attack_power")) # New line
	
	# 플레이어/적 리셋
	if player_node.has_method("reset_for_next_battle"): player_node.reset_for_next_battle()
	if enemy_node.has_method("reset_for_next_battle"): enemy_node.reset_for_next_battle()
	
	# UI 업데이트
	if ui_manager:
		ui_manager.show_screen(UIManager.Screen.BATTLE_HUD)
	
	player_node.update_hp_label()
	enemy_node.update_hp_label()
	
	# StageInfoHUD 업데이트
	if stage_info_hud:
		stage_info_hud.show()
		stage_info_hud.update_stage_info(current_stage, current_battle_count)


# =============================================================================
# 전투 행동 시그널 핸들러
# =============================================================================

func handle_attack_stance():
	print("GameManager: 공격 자세 선택됨")

func handle_defense_stance():
	print("GameManager: 방어 자세 선택됨")

func handle_dodge_stance():
	print("GameManager: 회피 자세 선택됨")

func use_skill_1():
	print("GameManager: 스킬 1 사용")

func use_skill_2():
	print("GameManager: 스킬 2 사용")

func handle_start_combat():
	print("GameManager: 전투 시작")
	current_game_phase = GamePhase.COMBAT
	emit_signal("battle_started")

	# '다음 전투' 버튼 숨기기
	if ui_manager and ui_manager.has_method("set_next_battle_button_visible"):
		ui_manager.set_next_battle_button_visible(false)

	player_node.target = enemy_node
	enemy_node.target = player_node

	if battle_manager:
		battle_manager.start_battle(player_node, enemy_node, self)

func handle_battle_end(win: bool):
	print("GameManager: 전투 종료. 승리: ", win)
	current_game_phase = GamePhase.BATTLE_END
	emit_signal("battle_ended", win)

	if win:
		current_battle_count += 1
		can_roll_new_dice = true # 전투 승리 시 주사위 굴리기 활성화

		if current_battle_count > BOSS_BATTLE_COUNT:
			current_battle_count = 0
			current_stage += 1
			scene_manager.go_to_town(true) # Updated to use scene_manager
			return

		if player_node:
			var new_hp = min(player_node.get_stat("max_hp"), player_node.get_stat("current_hp") + player_node.get_stat("recovery_power"))
			player_node.set_stat("current_hp", new_hp)
			player_node.update_hp_label()

		# TODO: 전투 승리 후 다음 단계(예: 다음 전투 버튼 활성화)를 여기에 구현해야 합니다.
		print("전투 승리! 다음 로직 대기 중...")
	else:
		handle_retry()

func handle_retry():
	print("GameManager: 재도전. 상태를 초기화하고 씬을 다시 로드합니다.")
	can_roll_new_dice = false # 재도전 시 주사위 굴리기 비활성화
	current_stage = 1
	current_battle_count = 0
	if get_node("/root/DiceManager").player_dice_pool: get_node("/root/DiceManager").player_dice_pool.clear()
	scene_manager.reload_current_scene() # Updated to use scene_manager

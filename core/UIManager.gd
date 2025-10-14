class_name UIManager
extends CanvasLayer
signal start_game_button_pressed

enum SecondaryButtonAction {
	NONE,
	LOOT_OFFER_DECLINE,
	GAMBLE_DECLINE,
	GAMBLE_RESULT_CONTINUE,
	DEFEAT_RETRY,
	NEXT_BATTLE,
}

var game_manager: Node
var player_node: Character

# UI 요소 그룹
@onready var stat_slots = {
	"attack_power": $UIRoot/StatSlotsContainer/AttackPowerSlot,
	"max_hp": $UIRoot/StatSlotsContainer/MaxHPSlot,
	"defense": $UIRoot/StatSlotsContainer/DefenseSlot,
	"attack_speed": $UIRoot/StatSlotsContainer/AttackSpeedSlot,
	"recovery_power": $UIRoot/StatSlotsContainer/RecoveryPowerSlot
}
@onready var dice_labels_container = $UIRoot/DiceLabelsContainer
@onready var roll_dice_button = $UIRoot/Button
@onready var result_label = $UIRoot/ResultLabel
@onready var stage_info_label = $UIRoot/StageInfoLabel

# --- 선택지 및 진행 버튼 (기존 버튼 재사용) ---
@onready var primary_choice_button = $UIRoot/StartCombatButton # "전투 시작", "가져간다", "갬블한다" 등
@onready var secondary_choice_button = $UIRoot/NextBattleButton # "다음 전투", "그냥 둔다", "안전하게 간다", "계속", "재도전" 등

var status_popup_instance: Control
var _current_status_character: Character # 현재 스탯 팝업이 표시 중인 캐릭터
var dice_label_scene = preload("res://ui/elements/DiceLabel.tscn") # 동적 생성을 위해 주사위 라벨 씬을 미리 로드

func _ready():
	# --- 시그널 연결 ---
	roll_dice_button.connect("pressed", _on_roll_dice_button_pressed)
	primary_choice_button.connect("pressed", _on_primary_choice_button_pressed)
	secondary_choice_button.connect("pressed", _on_secondary_choice_button_pressed)

	for stat_name in stat_slots:
		var slot = stat_slots[stat_name]
		slot.ui_manager = self
		slot.stat_name = stat_name

	stage_info_label.visible = true

# --- UI 상태 변경 함수 --- #

func hide_all_ui():
	roll_dice_button.visible = false
	result_label.visible = false
	dice_labels_container.visible = false

	# 문제가 되는 버튼을 확실하게 숨기고 비활성화
	primary_choice_button.visible = false
	primary_choice_button.disabled = true
	primary_choice_button.text = ""
	
	secondary_choice_button.visible = false
	secondary_choice_button.disabled = true
	secondary_choice_button.text = ""

	for slot in stat_slots.values():
		slot.visible = false

# 1. 전리품 발견 (YES/NO)
func show_loot_offer(dice_sides: int):
	hide_all_ui()
	result_label.text = "새로운 주사위를 발견했습니다: D" + str(dice_sides)
	result_label.visible = true
	
	primary_choice_button.text = "가져간다"
	primary_choice_button.visible = true
	primary_choice_button.disabled = false
	
	secondary_choice_button.text = "그냥 둔다"
	secondary_choice_button.visible = true
	secondary_choice_button.disabled = false
	secondary_choice_button.set_meta("action_type", SecondaryButtonAction.LOOT_OFFER_DECLINE)

# 2. 갬블 제안 (YES/NO)
func show_gamble_prompt(message: String):
	hide_all_ui()
	result_label.text = message + "\n두 번째 주사위를 걸고 갬블하시겠습니까?"
	result_label.visible = true
	
	primary_choice_button.text = "갬블한다"
	primary_choice_button.visible = true
	primary_choice_button.disabled = false

	secondary_choice_button.text = "안전하게 간다"
	secondary_choice_button.visible = true
	secondary_choice_button.disabled = false
	secondary_choice_button.set_meta("action_type", SecondaryButtonAction.GAMBLE_DECLINE)

# 3. 갬블 결과 (Continue)
func show_gamble_result(success: bool, dice_sides: int):
	hide_all_ui()
	if success:
		result_label.text = "성공! 주사위 풀에 D" + str(dice_sides) + "가 추가되었습니다!"
	else:
		result_label.text = "실패... 획득했던 주사위가 부서졌습니다."
	result_label.visible = true
	
	secondary_choice_button.text = "계속"
	secondary_choice_button.visible = true
	secondary_choice_button.disabled = false
	secondary_choice_button.set_meta("action_type", SecondaryButtonAction.GAMBLE_RESULT_CONTINUE)

# 4. 패배 화면 (Retry)
func show_defeat_screen():
	hide_all_ui()
	result_label.text = "패배..."
	result_label.visible = true
	
	secondary_choice_button.text = "재도전"
	secondary_choice_button.visible = true
	secondary_choice_button.disabled = false
	secondary_choice_button.set_meta("action_type", SecondaryButtonAction.DEFEAT_RETRY)

# 5. 일반 승리 (Next Battle)
func show_next_battle_phase(button_text: String):
	hide_all_ui()
	result_label.visible = true
	secondary_choice_button.text = button_text
	secondary_choice_button.visible = true
	secondary_choice_button.disabled = false
	secondary_choice_button.set_meta("action_type", SecondaryButtonAction.NEXT_BATTLE)

# 6. 주사위 굴림 단계
func show_roll_dice_phase():
	hide_all_ui()
	roll_dice_button.text = "주사위 굴리기"
	roll_dice_button.visible = true
	roll_dice_button.disabled = false

# 7. 전투 직전 단계 (주사위 굴림 없음)
func show_pre_combat_phase():
	hide_all_ui()
	primary_choice_button.text = "전투 시작"
	primary_choice_button.visible = true
	primary_choice_button.disabled = false

# --- 버튼 콜백 함수 --- #

func _on_roll_dice_button_pressed():
	roll_dice_button.disabled = true
	if game_manager:
		game_manager.handle_roll_dice()

func _on_primary_choice_button_pressed():
	primary_choice_button.disabled = true
	secondary_choice_button.disabled = true
	
	match game_manager.current_game_phase:
		GameManager.GamePhase.ROLL_DICE_FOR_EXPEDITION, GameManager.GamePhase.COMBAT:
			game_manager.handle_start_combat()
		GameManager.GamePhase.LOOT_OFFER:
			game_manager.handle_loot_offer_accept()
		GameManager.GamePhase.LOOT_GAMBLE_PROMPT:
			game_manager.handle_gamble_accept()

func _on_secondary_choice_button_pressed():
	primary_choice_button.disabled = true
	secondary_choice_button.disabled = true

	match secondary_choice_button.get_meta("action_type"):
		SecondaryButtonAction.LOOT_OFFER_DECLINE:
			game_manager.handle_loot_offer_decline()
		SecondaryButtonAction.GAMBLE_DECLINE:
			game_manager.handle_gamble_decline()
		SecondaryButtonAction.GAMBLE_RESULT_CONTINUE:
			game_manager.handle_gamble_result_continue()
		SecondaryButtonAction.DEFEAT_RETRY:
			game_manager.handle_retry()
		SecondaryButtonAction.NEXT_BATTLE:
			game_manager.handle_next_battle()

# --- 기타 UI 업데이트 함수 --- #

func update_result_label(text: String):
	result_label.text = text
	result_label.visible = true

func update_dice_labels(rolls: Array):
	roll_dice_button.visible = false
	dice_labels_container.visible = true
	primary_choice_button.visible = false

	for slot in stat_slots.values():
		slot.visible = true

	var dice_labels = dice_labels_container.get_children()
	# 필요하면 주사위 라벨 추가 생성
	while dice_labels.size() < rolls.size():
		var new_label = dice_label_scene.instantiate()
		dice_labels_container.add_child(new_label)
		dice_labels.append(new_label) # 배열에도 추가

	for i in range(dice_labels.size()):
		var dice_label = dice_labels[i]
		if i < rolls.size():
			dice_label.text = str(rolls[i])
			dice_label.dice_value = rolls[i]
			dice_label.visible = true
			dice_label.mouse_filter = Control.MOUSE_FILTER_STOP
			dice_label.is_used = false
		else:
			dice_label.visible = false # 남는 라벨은 숨김

func check_all_dice_used():
	var all_used = true
	for label in dice_labels_container.get_children():
		if label.dice_value > 0 and label.visible:
			all_used = false
			break
	if all_used:
		primary_choice_button.text = "전투 시작"
		primary_choice_button.visible = true
		primary_choice_button.disabled = false

func reset_dice_and_slots():
	for stat_name in stat_slots:
		var slot = stat_slots[stat_name] as StatSlot
		if slot:
			slot.reset_slot()
	
	for dice_label_node in dice_labels_container.get_children():
		var dice_label = dice_label_node as DiceLabel
		if dice_label:
			dice_label.is_used = false
			dice_label.visible = true
			dice_label.text = "?"
			dice_label.dice_value = 0

func update_stage_info(current_stage: int, current_battle_count: int):
	var stage_text = str(current_stage) + "스테이지 "
	var progress_text = ""
	var slot_types = ["normal", "normal", "normal", "loot", "normal", "normal", "loot", "boss"]

	for i in range(slot_types.size()):
		var slot_index = i + 1
		var symbol = ""
		if slot_index <= current_battle_count:
			match slot_types[i]:
				"normal": symbol = "●"
				"loot": symbol = "◈"
				"boss": symbol = "■"
		else:
			match slot_types[i]:
				"normal": symbol = "○"
				"loot": symbol = "◇"
				"boss": symbol = "□"
		progress_text += symbol
		if i < slot_types.size() - 1:
			progress_text += "─"
	stage_info_label.text = stage_text + progress_text

func update_player_stats_ui(p_node: Character):
	for stat_name in stat_slots:
		var slot = stat_slots[stat_name]
		if slot.has_node("Value"):
			var value_label = slot.get_node("Value")
			var stat_value = 0
			match stat_name:
				"attack_power": stat_value = p_node.get_attack_power()
				"max_hp": stat_value = p_node.get_max_hp()
				"defense": stat_value = p_node.get_defense()
				"attack_speed": stat_value = p_node.get_attack_speed()
				"recovery_power": stat_value = p_node.get_recovery_power()
				"max_mp": stat_value = p_node.get_max_mp()
				"current_mp": stat_value = p_node.get_current_mp()
				"luck": stat_value = p_node.get_luck()
				"resistance": stat_value = p_node.get_resistance()
				_:
					stat_value = 0 # Fallback

			value_label.text = str(stat_value)

func show_status_popup(character: Character):
	print("UIManager: show_status_popup 호출됨. 캐릭터:", character.name)

	# 팝업 인스턴스가 유효하지 않으면 새로 생성
	if not is_instance_valid(status_popup_instance):
		var status_popup_scene = load("res://ui/StatusPopup.tscn")
		status_popup_instance = status_popup_scene.instantiate()
		add_child(status_popup_instance)
	
	# 현재 표시 중인 캐릭터와 클릭된 캐릭터가 같으면 팝업을 토글
	if _current_status_character == character:
		if status_popup_instance.visible:
			hide_status_popup() # 팝업이 보이면 숨김
		else:
			status_popup_instance.show() # 팝업이 숨겨져 있으면 보임
			status_popup_instance.show_stats(character) # 스탯 업데이트
		_current_status_character = null if not status_popup_instance.visible else character
		return
	
	# 다른 캐릭터를 클릭했거나 팝업이 처음 열리는 경우
	status_popup_instance.show_stats(character)
	_current_status_character = character # 현재 표시 중인 캐릭터 업데이트
	status_popup_instance.show() # 팝업을 명시적으로 보이게 함

	var screen_size = get_viewport().get_visible_rect().size
	var character_screen_pos = character.global_position
	var popup_width = status_popup_instance.size.x
	var popup_height = status_popup_instance.size.y
	var target_x = character_screen_pos.x + 50
	var target_y = character_screen_pos.y - popup_height / 2
	target_x = clamp(target_x, 0, screen_size.x - popup_width)
	target_y = clamp(target_y, 0, screen_size.y - popup_height)
	status_popup_instance.position = Vector2(target_x, target_y)
	status_popup_instance.modulate = Color(1, 1, 1, 0.7)


func hide_status_popup():
	if is_instance_valid(status_popup_instance):
		status_popup_instance.hide()
		_current_status_character = null # 팝업 숨김 시 현재 캐릭터 정보 초기화

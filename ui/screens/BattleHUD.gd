# BattleHUD.gd
extends CanvasLayer

# =============================================================================
# 시그널 (Signals)
# =============================================================================
signal attack_stance_selected
signal defense_stance_selected
signal dodge_stance_selected
signal skill_1_used
signal skill_2_used
signal inventory_opened
signal destiny_design_opened
signal next_battle_requested # 다음 전투 시작 요청 시그널

# =============================================================================
# 노드 참조 (Node References)
# =============================================================================
@onready var destiny_design_button = $DestinyDesignButton
@onready var next_battle_button = $NextBattleButton

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================
func _ready():
	# 각 버튼의 pressed 시그널을 내부 핸들러 함수와 연결합니다.
	$BattleControls/AttackButton.pressed.connect(_on_attack_button_pressed)
	$BattleControls/DefenseButton.pressed.connect(_on_defense_button_pressed)
	$BattleControls/DodgeButton.pressed.connect(_on_dodge_button_pressed)
	$BattleControls/Skill1Button.pressed.connect(_on_skill_1_button_pressed)
	$BattleControls/Skill2Button.pressed.connect(_on_skill_2_button_pressed)
	$InventoryButton.pressed.connect(_on_inventory_button_pressed)
	
	if destiny_design_button: destiny_design_button.pressed.connect(_on_destiny_design_button_pressed)
	if next_battle_button: next_battle_button.pressed.connect(_on_next_battle_button_pressed)
	
	# 시작 시 버튼 상태 초기화
	set_next_battle_button_visible(false)

# =============================================================================
# 공개 함수 (Public Methods)
# =============================================================================
func set_destiny_button_enabled(is_enabled: bool):
	if destiny_design_button: destiny_design_button.disabled = not is_enabled

func set_next_battle_button_visible(p_is_visible: bool):
	if next_battle_button: next_battle_button.visible = p_is_visible

# =============================================================================
# 시그널 핸들러 (Signal Handlers)
# =============================================================================
func _on_attack_button_pressed():
	emit_signal("attack_stance_selected")

func _on_defense_button_pressed():
	emit_signal("defense_stance_selected")

func _on_dodge_button_pressed():
	emit_signal("dodge_stance_selected")

func _on_skill_1_button_pressed():
	emit_signal("skill_1_used")

func _on_skill_2_button_pressed():
	emit_signal("skill_2_used")

func _on_inventory_button_pressed():
	emit_signal("inventory_opened")

func _on_destiny_design_button_pressed():
	emit_signal("destiny_design_opened")

func _on_next_battle_button_pressed():
	emit_signal("next_battle_requested")

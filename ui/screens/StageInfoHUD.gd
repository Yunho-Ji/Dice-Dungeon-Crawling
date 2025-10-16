# StageInfoHUD.gd
# 설명: 게임의 현재 스테이지 및 전투 진행 상황을 표시하는 UI입니다.
extends Control

# =============================================================================
# 노드 참조 (Node References)
# =============================================================================

@onready var stage_label = $StageLabel

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	# 이 컨트롤이 마우스 입력을 가로채지 않도록 설정합니다. (클릭 버그의 원인)
	mouse_filter = MOUSE_FILTER_IGNORE
	
	# 초기에는 숨겨진 상태로 시작합니다.
	self.visible = false

# =============================================================================
# 공개 함수 (Public Methods)
# =============================================================================

# 스테이지 정보를 업데이트하고 표시합니다.
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
	stage_label.text = stage_text + progress_text

func show_hud():
	self.visible = true

func hide_hud():
	self.visible = false

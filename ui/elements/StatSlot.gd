class_name StatSlot
extends Panel

@export var stat_name: String = ""

var ui_manager: Node # UIManager 참조
var is_filled: bool = false # 슬롯이 채워졌는지 여부

func _ready():
	pass

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if is_filled: # 이미 채워진 슬롯은 드롭 불가
		return false
	if data is Dictionary and data.has("type") and data.type == "dice":
		return true
	return false

func _drop_data(_at_position: Vector2, data: Variant):
	if data is Dictionary and data.has("type") and data.type == "dice":
		var dice_value = data.value
		var original_label = data.original_label
		var _dice_index = ui_manager.dice_labels_container.get_children().find(original_label) # 주사위 라벨의 인덱스 찾기

		if ui_manager:
			ui_manager.player_node.apply_dice_to_stat(stat_name, dice_value)
			original_label.visible = false # 드롭된 주사위 숨기기
			original_label.is_used = true # 사용됨으로 표시 (DiceLabel.gd의 is_used 변수 사용)
			ui_manager.check_all_dice_used()
		is_filled = true # 슬롯 채워짐
		modulate = Color(0.8, 0.8, 0.8) # 시각적 피드백 (어둡게)

func reset_slot():
	is_filled = false
	modulate = Color(1, 1, 1) # 기본 색상으로 원복

extends Label
class_name DiceLabel

var dice_value: int = 0
var original_position: Vector2
var is_used: bool = false # 추가: 주사위가 사용되었는지 여부

func _ready():
	original_position = position

func _get_drag_data(_at_position: Vector2):
	if is_used: return null # 사용된 주사위는 드래그 불가

	var preview = duplicate() # 드래그 프리뷰 생성
	preview.modulate = Color(1, 1, 1, 0.7) # 투명도 조절
	set_drag_preview(preview)

	var data = {"type": "dice", "value": dice_value, "original_label": self}
	return data

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false # Label은 드롭 대상이 아님

func _drop_data(_at_position: Vector2, _data: Variant):
	pass # Label은 드롭 대상이 아님

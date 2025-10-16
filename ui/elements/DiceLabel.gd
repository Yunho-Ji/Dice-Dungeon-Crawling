extends Label
class_name DiceLabel

var dice_value: int = 0
var original_position: Vector2
var is_used: bool = false # 추가: 주사위가 사용되었는지 여부

func _ready():
	original_position = position

func _get_drag_data(_at_position: Vector2):
	# 드래그 미리보기용 라벨을 만듭니다.
	var preview = Label.new()
	preview.text = text
	preview.modulate = Color(1, 1, 1, 0.7) # 반투명하게
	set_drag_preview(preview)

	# 드래그할 데이터를 딕셔너리로 묶습니다.
	var data = {
		"type": "dice",
		"value": dice_value,
		"source_label": self
	}
	return data

func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false # Label은 드롭 대상이 아님

func _drop_data(_at_position: Vector2, _data: Variant):
	pass # Label은 드롭 대상이 아님

# InventorySlotUI.gd
# 인벤토리 그리드의 배경 한 칸을 나타내는 UI
extends PanelContainer
class_name InventorySlotUI

var grid_position: Vector2i = Vector2i.ZERO

func _ready():
	custom_minimum_size = Vector2(40, 40) # 기존 Apeloot 사이즈와 맞춤
	# 시각적 스타일 설정 (필요 시 수정)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	add_theme_stylebox_override("panel", style)

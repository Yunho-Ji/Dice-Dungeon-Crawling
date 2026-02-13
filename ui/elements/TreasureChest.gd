extends Node2D

var loot_data: Dictionary = {}
var is_opened: bool = false

@onready var area_2d = $Area2D

func _ready():
	add_to_group("treasure_chests")

func setup(p_loot: Dictionary):
	loot_data = p_loot
	is_opened = false
	visible = true

func _on_input_event(_viewport, event, _shape_idx):
	if is_opened: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_chest()

func open_chest():
	is_opened = true
	print("보물상자를 열었습니다!")
	
	# GameManager에게 전리품 화면 표시 요청
	var gm = get_node("/root/GameManager")
	if gm.has_method("_show_loot_offer"):
		gm._show_loot_offer(loot_data)
	
	# 열린 연출 (임시로 투명도 조절 또는 숨김)
	queue_free() # 일단은 획득 후 제거 (나중에 열린 상자 스프라이트로 변경 가능)

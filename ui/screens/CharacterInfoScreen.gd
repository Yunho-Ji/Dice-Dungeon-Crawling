# CharacterInfoScreen.gd
# 캐릭터의 상세 스탯과 장비 상태를 한눈에 보여주는 정보창 프로토타입입니다.
extends Control

signal closed

# --- 프리로드 ---
const StatSlotScene = preload("res://ui/elements/StatSlot.tscn")

# --- 노드 참조 ---
@onready var stat_grid = $MainPanel/HBox/LeftPage/StatGrid
@onready var equip_grid = $MainPanel/HBox/RightPage/EquipGrid
@onready var hp_label = $MainPanel/HBox/RightPage/DerivedStats/HPLabel
@onready var mp_label = $MainPanel/HBox/RightPage/DerivedStats/MPLabel
@onready var detail_stats_label = $MainPanel/HBox/RightPage/DerivedStats/DetailLabel
@onready var close_button = $MainPanel/CloseButton

# --- 상수 ---
const CORE_STATS = ["agi", "vit", "int_stat", "atk", "spd", "res", "spi", "rec"]

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	_initialize_ui()
	_update_stats()
	_update_equipment()
	
	# [리팩토링] 람다 함수 대신 명시적 메서드 연결로 메모리 누수(Memory Leak) 방지
	SignalBus.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed(_slot_key: String, _item_data):
	_update_all()

func _initialize_ui():
	# 기존 스탯 슬롯 초기화
	for child in stat_grid.get_children():
		child.queue_free()
	
	var stats_obj = PlayerManager.current_player_stats
	if stats_obj:
		for s_name in CORE_STATS:
			var stat_res = stats_obj.get_stat(s_name)
			if stat_res:
				var slot = StatSlotScene.instantiate()
				stat_grid.add_child(slot)
				slot.set_stat(s_name, stat_res)
				# 프로토타입용: 드롭 기능 비활성화 (보기 전용)
				slot.set_process_input(false)

func _update_all():
	_update_stats()
	_update_equipment()

func _update_stats():
	var stats_obj = PlayerManager.current_player_stats
	if not stats_obj: return
	
	# 파생 스탯 업데이트
	var hp = stats_obj.get_stat("health")
	var mp = stats_obj.get_stat("current_mp")
	
	if hp: hp_label.text = "최대 체력 (HP): %d" % hp.computed_value
	if mp: mp_label.text = "최대 마력 (MP): %d" % mp.computed_value
	
	# 기타 전투 수치 (StatManager 활용)
	var move = 3 # 기본값
	var attack_range = 1 # 기본값
	if GameManager.player_node:
		move = GameManager.player_node.move_range
		attack_range = GameManager.player_node.attack_range
		
	detail_stats_label.text = "이동력: %d | 사거리: %d" % [move, attack_range]

func _update_equipment():
	# 3x3 장비 그리드 업데이트 (프로토타입은 텍스트로 우선 표시)
	for child in equip_grid.get_children():
		child.queue_free()
		
	var slots = [
		"accessory_1", "head", "accessory_2",
		"main_weapon", "top", "sub_weapon",
		"accessory_3", "shoes", "accessory_4"
	]
	
	for slot_key in slots:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(60, 60)
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 10)
		
		var item = PlayerManager.equipment.get(slot_key)
		if item:
			label.text = item.get("name", "아이템")
			panel.modulate = Color.GOLD
		else:
			label.text = slot_key.to_upper().replace("_", "\n")
			panel.modulate = Color(0.5, 0.5, 0.5, 0.5)
			
		panel.add_child(label)
		equip_grid.add_child(panel)

func _on_close_pressed():
	closed.emit()

# _input은 GameManager에서 전담 처리하므로 제거하거나 비활성화합니다.

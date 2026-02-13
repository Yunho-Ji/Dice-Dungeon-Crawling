# LootOfferScreen.gd
extends CanvasLayer

signal closed

@onready var title_label = %TitleLabel
@onready var gold_label = %GoldLabel
@onready var items_container = %ItemsContainer
@onready var confirm_button = %ConfirmButton

var current_loot = {}

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)

func setup(loot_data: Dictionary):
	current_loot = loot_data
	
	# 타이틀 설정
	if loot_data.get("is_boss", false):
		title_label.text = "보스 처치 완료!"
	else:
		title_label.text = "전투 승리!"
		
	# 골드 표시
	var gold = loot_data.get("gold", 0)
	gold_label.text = "획득 골드: %d G" % gold
	
	# 아이템 표시
	_clear_items()
	var items = loot_data.get("items", [])
	for item_info in items:
		_add_item_display(item_info)
		
	# 주사위 보상 표시 (있을 경우)
	var dice = loot_data.get("dice", [])
	for dice_sides in dice:
		_add_dice_display(dice_sides)

func _clear_items():
	for child in items_container.get_children():
		child.queue_free()

func _add_item_display(item_info: Dictionary):
	var item_id = item_info.get("id", "")
	var item_data = Apeloot.items.get(item_id, {})
	var pattern_name = item_data.get("pattern", "1x1")
	
	# 카드형 패널 생성
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 100)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1) # 실루엣 배경
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)
	
	# 아이템의 실제 이름 대신 실루엣(크기) 정보만 노출
	var label = Label.new()
	label.text = pattern_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(label)
	
	var status_label = Label.new()
	status_label.text = "미식별"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.modulate = Color(0.6, 0.6, 0.6)
	vbox.add_child(status_label)

	# 획득 버튼 (카드 자체를 클릭 가능하게 하거나 버튼 추가)
	var take_btn = Button.new()
	take_btn.text = "챙기기"
	take_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	take_btn.pressed.connect(func(): 
		if InventoryManager.try_add_item(item_id):
			current_loot["items"].erase(item_info)
			card.queue_free()
		else:
			status_label.text = "공간 부족!"
			status_label.modulate = Color.RED
	)
	vbox.add_child(take_btn)
	
	items_container.add_child(card)

func _add_dice_display(sides: int):
	var label = Label.new()
	label.text = "[주사위] D%d 획득!" % sides
	label.modulate = Color.ORANGE
	items_container.add_child(label)

func _on_confirm_pressed():
	# 실제 보상 지급 로직 호출
	var success = _apply_loot()
	if success:
		emit_signal("closed")
		queue_free()
	else:
		# 일부 아이템이 들어가지 않았을 경우 경고 표시
		gold_label.text = "인벤토리 공간이 부족합니다!"
		gold_label.modulate = Color.RED

func _apply_loot() -> bool:
	# 골드 지급
	var gold = current_loot.get("gold", 0)
	if gold > 0:
		EconomyManager.add_gold(gold)
		current_loot["gold"] = 0 
		
	# 주사위 지급
	var dice = current_loot.get("dice", [])
	if dice.size() > 0:
		for sides in dice:
			DiceManager.add_pending_reward(sides)
			DiceManager.confirm_reward(DiceManager.pending_rewards.size() - 1)
		current_loot["dice"] = []
		DiceManager.enable_roll()
	
	return true

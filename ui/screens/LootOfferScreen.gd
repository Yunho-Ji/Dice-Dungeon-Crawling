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

const LOOT_ITEM_SLOT_SCENE = preload("res://ui/elements/LootItemSlot.tscn")

func _add_item_display(item_info: Dictionary):
	var item_id = item_info.get("id", "")
	
	var slot = LOOT_ITEM_SLOT_SCENE.instantiate()
	items_container.add_child(slot)
	
	slot.setup(item_id, item_info)
	slot.take_requested.connect(_on_item_take_requested.bind(slot))

func _on_item_take_requested(item_id: String, item_data: Dictionary, slot_node: Node):
	# item_id가 유효한지 확인
	if item_id == "" or not Apeloot.items.has(item_id):
		print("ERROR: Invalid item_id: ", item_id)
		return

	if InventoryManager.try_add_item(item_id):
		# 배열에서 아이템 정보를 안전하게 제거
		if current_loot.has("items") and current_loot["items"] is Array:
			current_loot["items"].erase(item_data)
		slot_node.queue_free()
	else:
		gold_label.text = "인벤토리 공간 부족!"
		gold_label.modulate = Color.RED
		# 1초 뒤 원래 텍스트로 복구하는 연출 추가 가능
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(gold_label):
			var gold = current_loot.get("gold", 0)
			gold_label.text = "획득 골드: %d G" % gold
			gold_label.modulate = Color.WHITE

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

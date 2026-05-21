# LootOfferScreen.gd
extends CanvasLayer

signal closed

@onready var title_label = %TitleLabel
@onready var gold_label = %GoldLabel
@onready var items_container = %ItemsContainer
@onready var confirm_button = %ConfirmButton

var current_loot = {} # LootManager의 데이터를 참조하는 용도

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
	# LootManager를 통해 획득 시도
	var loot_manager = get_node("/root/LootManager")
	if loot_manager.claim_item(item_data):
		# 성공 시 UI에서 제거
		slot_node.queue_free()
	else:
		# 실패 시 시각적 피드백 (공간 부족 등)
		gold_label.text = "인벤토리 공간 부족!"
		gold_label.modulate = Color.RED
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(gold_label):
			var gold = loot_manager.get_loot_data().get("gold", 0)
			gold_label.text = "획득 골드: %d G" % gold
			gold_label.modulate = Color.WHITE

func _add_dice_display(sides: int):
	var label = Label.new()
	label.text = "[주사위] D%d 획득!" % sides
	label.modulate = Color.ORANGE
	items_container.add_child(label)

func _on_confirm_pressed():
	# LootManager에게 잔여 보상(골드, 주사위) 수령 요청
	var loot_manager = get_node("/root/LootManager")
	loot_manager.claim_remaining_rewards()
	
	# 아이템이 남아있다면 경고 (선택 사항 - 기획에 따라 다름)
	if loot_manager.has_remaining_items():
		gold_label.text = "남겨진 아이템이 있습니다!"
		gold_label.modulate = Color.YELLOW
		# 잠시 후 닫을지, 아니면 강제로 남게 할지 결정. 여기선 일단 닫음.
		await get_tree().create_timer(0.5).timeout

	emit_signal("closed")
	queue_free()

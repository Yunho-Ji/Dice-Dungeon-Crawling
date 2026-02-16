extends PanelContainer

signal closed

@onready var item_list = $VBox/Scroll/ItemList
@onready var message_label = $VBox/MessageLabel
@onready var close_button = $VBox/CloseButton

# 판매할 아이템 목록
var shop_items = [
	{"id": "leather_top", "price": 150, "name": "가죽 상의 (경갑)"},
	{"id": "iron_plate", "price": 300, "name": "강철 흉갑 (중갑)"},
	{"id": "wizard_robe", "price": 250, "name": "마법사의 로브 (천)"},
	{"id": "leather_boots", "price": 90, "name": "가죽 장화 (경갑)"}
]

func _ready():
	custom_minimum_size = Vector2(500, 400)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)
	
	var title = Label.new()
	title.text = "--- 방어구 상점 ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = "좋은 물건이 많으니 둘러보세요. (이용 시 1시간 소모)"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 250)
	vbox.add_child(scroll)
	
	item_list = VBoxContainer.new()
	item_list.name = "ItemList"
	scroll.add_child(item_list)
	
	_refresh_item_list()
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "상점 나가기"
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _refresh_item_list():
	for child in item_list.get_children():
		child.queue_free()
		
	for item in shop_items:
		var hbox = HBoxContainer.new()
		
		var name_label = Label.new()
		name_label.text = item.name
		name_label.custom_minimum_size = Vector2(250, 0)
		hbox.add_child(name_label)
		
		var price_label = Label.new()
		price_label.text = "%d G" % item.price
		price_label.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(price_label)
		
		var buy_btn = Button.new()
		buy_btn.text = "구매"
		buy_btn.pressed.connect(_on_buy_pressed.bind(item))
		hbox.add_child(buy_btn)
		
		item_list.add_child(hbox)

func _on_buy_pressed(item_data: Dictionary):
	var em = get_node("/root/EconomyManager")
	var im = get_node("/root/InventoryManager")
	var tm = get_node("/root/TownManager")
	
	if em.get_gold() < item_data.price:
		message_label.text = "골드가 부족합니다!"
		return
		
	# 아이템 구매 시도
	if im.try_add_item(item_data.id):
		em.spend_gold(item_data.price)
		message_label.text = "%s을(를) 구매했습니다." % item_data.name
		
		# 시간 소모
		tm.spend_time_for_facility()
		print("Shop: 구매 완료. 시간 경과.")
	else:
		message_label.text = "가방에 공간이 없습니다!"

func _on_close_pressed():
	closed.emit()
	queue_free()

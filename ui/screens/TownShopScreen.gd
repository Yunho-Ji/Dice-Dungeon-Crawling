extends PanelContainer

# TownShopScreen.gd
# 마을 상점 화면: 아이템 구매 및 판매 기능을 제공합니다.

signal closed

@onready var item_list = $VBox/Scroll/ItemList
@onready var message_label = $VBox/MessageLabel
@onready var close_button = $VBox/CloseButton

enum ShopMode { BUY, SELL }
var current_mode = ShopMode.BUY

# 판매할 아이템 ID 목록 (DataManager의 ID와 일치해야 함)
var shop_item_ids = [
	"basic_sword", "basic_bow", "basic_cloth_armor", "basic_leather_boots",
	"test_necklace_common", "test_ring_rare", "test_consumable_585"
]

func _ready():
	custom_minimum_size = Vector2(550, 500)
	
	# 기존 자식 노드 제거 (새로운 레이아웃 구성을 위해)
	for child in get_children():
		child.queue_free()
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 15)
	add_child(vbox)
	
	var title = Label.new()
	title.text = "--- 마을 잡화점 ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 탭 버튼 추가
	var tab_hbox = HBoxContainer.new()
	tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_hbox)
	
	var buy_tab = Button.new()
	buy_tab.text = " [ 구매 ] "
	buy_tab.pressed.connect(_set_mode.bind(ShopMode.BUY))
	tab_hbox.add_child(buy_tab)
	
	var sell_tab = Button.new()
	sell_tab.text = " [ 판매 ] "
	sell_tab.pressed.connect(_set_mode.bind(ShopMode.SELL))
	tab_hbox.add_child(sell_tab)
	
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = "어서오세요! 무엇을 도와드릴까요?"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(message_label)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	item_list = VBoxContainer.new()
	item_list.name = "ItemList"
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)
	
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "상점 나가기"
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)
	
	_refresh_ui()

func _set_mode(mode):
	current_mode = mode
	_refresh_ui()

func _refresh_ui():
	for child in item_list.get_children():
		child.queue_free()
		
	if current_mode == ShopMode.BUY:
		_refresh_buy_list()
	else:
		_refresh_sell_list()

func _refresh_buy_list():
	message_label.text = "필요한 물건을 골라보세요. (1시간 소모)"
	for item_id in shop_item_ids:
		var item_data = DataManager.get_item(item_id)
		if item_data.is_empty(): continue
			
		var price = _get_item_price(item_id, item_data)
		_add_item_row(item_data.get("name", item_id), price, "구매", _on_buy_pressed.bind(item_id, price, item_data.get("name", item_id)))

func _refresh_sell_list():
	message_label.text = "가방에 있는 물건을 매입합니다. (정직한 가격!)"
	var player_items = PlayerManager.inventory_data.items
	
	if player_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "가방이 비어있습니다."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list.add_child(empty_label)
		return
		
	for item in player_items:
		# 금화 더미는 판매 불가
		if item.id.begins_with("gold_pile_"): continue
		
		var item_data = item.get_data()
		var buy_price = _get_item_price(item.id, item_data)
		var sell_price = max(1, int(buy_price * 0.5))
		
		_add_item_row(item_data.get("name", item.id), sell_price, "판매", _on_sell_pressed.bind(item))

func _add_item_row(name_text: String, price: int, button_text: String, callback: Callable):
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 40)
	
	var name_label = Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var price_label = Label.new()
	price_label.text = "%d G" % price
	price_label.custom_minimum_size = Vector2(80, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer)
	
	var btn = Button.new()
	btn.text = button_text
	btn.custom_minimum_size = Vector2(80, 0)
	btn.pressed.connect(callback)
	hbox.add_child(btn)
	
	item_list.add_child(hbox)

func _get_item_price(_item_id: String, item_data: Dictionary) -> int:
	if item_data.has("price") and int(item_data.price) > 0:
		return int(item_data.price)
	
	var grade = item_data.get("grade", "common")
	match grade:
		"common": return 50
		"rare": return 200
		"epic": return 800
		"relic": return 2500
		_: return 100

func _on_buy_pressed(item_id: String, price: int, item_name: String):
	if EconomyManager.get_gold() < price:
		message_label.text = "골드가 부족합니다! (필요: %d G)" % price
		return
		
	if InventoryManager.try_add_item(item_id):
		EconomyManager.spend_gold(price)
		message_label.text = "[%s] 구매 완료! (-%d G)" % [item_name, price]
		if TownManager: TownManager.spend_time_for_facility()
		_refresh_ui()
	else:
		message_label.text = "가방에 공간이 없습니다!"

func _on_sell_pressed(item: InventoryItem):
	var item_name = item.get_data().get("name", item.id)
	InventoryManager.sell_item(item)
	message_label.text = "[%s] 판매 완료!" % item_name
	_refresh_ui()

func _on_close_pressed():
	closed.emit()
	queue_free()

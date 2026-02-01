# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리를 표시하는 UI입니다.
# '가방' 버튼을 누르면 표시되며, 아이템을 확인하고 사용할 수 있습니다.
extends CanvasLayer

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed

var inventory_interface: GridInventory = null

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	print("DEBUG: InventoryScreen _ready called.")
	
	# 노드 경로: CenterContainer -> MainPanel -> VBox
	var vbox = $CenterContainer/MainPanel/VBox
	
	if not vbox:
		printerr("ERROR: VBox container not found!")
		return
		
	# InventoryInterface 찾기
	if vbox.has_node("InventoryInterface"):
		inventory_interface = vbox.get_node("InventoryInterface")
		print("DEBUG: InventoryInterface node linked.")
	else:
		printerr("ERROR: InventoryInterface node NOT found.")

	# 헤더 영역 노드 연결
	var header = vbox.get_node("Header")
	
	# 닫기 버튼 연결
	if header and header.has_node("CloseButton"):
		header.get_node("CloseButton").pressed.connect(_on_close_button_pressed)
	
	# 디버그 골드 버튼 연결 및 표시 설정
	if header and header.has_node("DebugGoldButton"):
		var debug_btn = header.get_node("DebugGoldButton")
		debug_btn.pressed.connect(_on_debug_gold_button_pressed)
		debug_btn.visible = true # 테스트를 위해 항상 표시 (나중에 제거)
	
	hide_screen()

# =============================================================================
# 공개 함수 (Public Methods)
# =============================================================================

func show_screen():
	print("InventoryScreen: 화면 표시")
	self.visible = true
	
	if not inventory_interface:
		printerr("ERROR: inventory_interface is null.")
		return
		
	update_gold_display()

	# 테스트용 아이템 생성 제거 (Clean Start)
	# if inventory_interface.items.size() == 0:
	# 	_test_inventory()

func update_gold_display():
	var header = $CenterContainer/MainPanel/VBox/Header
	if header and header.has_node("GoldLabel"):
		var gold = PlayerManager.get_gold()
		header.get_node("GoldLabel").text = str(gold) + " G"

func hide_screen():
	print("InventoryScreen: 화면 숨김")
	self.visible = false

# =============================================================================
# 내부 함수 (Private Methods)
# =============================================================================

func _test_inventory():
	print("InventoryScreen: 테스트 아이템 생성 중...")
	# Apeloot에 정의된 아이템들을 랜덤하게 몇 개 추가해봅니다.
	var test_items = ["steak", "pickaxe", "ketchup", "glasses"]
	for i in range(5):
		var item_id = test_items.pick_random()
		var item = inventory_interface.spawn_item(item_id)
		# 자동 배치 시도
		if not inventory_interface.try_fit_and_place(item):
			item.queue_free() # 배치 실패 시 제거
			print("InventoryScreen: 아이템 배치 실패 - " + item_id)
		else:
			print("InventoryScreen: 아이템 배치 성공 - " + item_id)

# =============================================================================
# 시그널 핸들러 (Signal Handlers)
# =============================================================================

func _on_debug_gold_button_pressed():
	print("DEBUG: +1000 Gold added via button.")
	PlayerManager.add_gold(1000)
	update_gold_display()

func _on_close_button_pressed():
	# 닫기 버튼이 눌리면 화면을 숨기고 시그널을 보냅니다.
	hide_screen()
	emit_signal("inventory_closed")

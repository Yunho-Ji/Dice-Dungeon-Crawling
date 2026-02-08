# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리 및 장비를 표시하는 UI입니다.
extends CanvasLayer

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed

# --- 노드 참조 ---
@onready var main_panel = $CenterContainer/MainPanel
@onready var inventory_interface = $CenterContainer/MainPanel/VBox/MainHBox/InventorySection/InventoryInterface
@onready var gold_label = $CenterContainer/MainPanel/VBox/Footer/GoldLabel
@onready var close_button = $CenterContainer/MainPanel/VBox/Header/CloseButton

# 장비 슬롯 참조
@onready var head_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/HeadSlot
@onready var top_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/TopSlot
@onready var bottom_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/BottomSlot
@onready var shoes_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/ShoesSlot
@onready var left_hand_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/LeftHandSlot
@onready var right_hand_slot = $CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/RightHandSlot
@onready var acc_slots = [
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc1,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc2,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc3,
	$CenterContainer/MainPanel/VBox/MainHBox/EquipmentSection/SlotsGrid/Acc4
]

func _ready():
	print("DEBUG: InventoryScreen _ready called.")
	
	# 시그널 연결
	close_button.pressed.connect(_on_close_button_pressed)
	SignalBus.connect("gold_changed", _on_gold_changed)
	
	_setup_equipment_slots()
	hide_screen()

# 장비 슬롯 구분용 초기 설정
func _setup_equipment_slots():
	head_slot.tooltip_text = "머리"
	top_slot.tooltip_text = "상의"
	bottom_slot.tooltip_text = "하의"
	shoes_slot.tooltip_text = "신발"
	left_hand_slot.tooltip_text = "왼손 (무기/방패)"
	right_hand_slot.tooltip_text = "오른손 (무기/방패)"
	for i in range(acc_slots.size()):
		acc_slots[i].tooltip_text = "장신구 %d" % (i + 1)

func show_screen():
	print("InventoryScreen: 화면 표시")
	self.visible = true
	update_gold_display()
	_refresh_equipment_visuals()

func hide_screen():
	self.visible = false

func update_gold_display(gold_amount: int = -1):
	if gold_amount == -1:
		gold_amount = EconomyManager.get_gold()
	gold_label.text = "소지 골드: %d G" % gold_amount

# [신규] 장비 슬롯 시각화 업데이트
func _refresh_equipment_visuals():
	var pm = get_node("/root/PlayerManager")
	# 현재 PlayerManager의 equipment 데이터를 바탕으로 슬롯의 아이콘 등을 업데이트합니다.
	# (Apeloot 연동 로직 추가 예정)
	pass

# --- 시그널 핸들러 ---
func _on_gold_changed(new_gold: int, _delta: int):
	update_gold_display(new_gold)

func _on_close_button_pressed():
	hide_screen()
	emit_signal("inventory_closed")

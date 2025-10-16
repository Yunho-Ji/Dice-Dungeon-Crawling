# InventoryScreen.gd
# 화면 설명: 플레이어의 인벤토리를 표시하는 UI입니다.
# '가방' 버튼을 누르면 표시되며, 아이템을 확인하고 사용할 수 있습니다.
extends Control

# 인벤토리가 닫힐 때 발생하는 시그널입니다.
signal inventory_closed

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	# '닫기' 버튼의 시그널을 연결합니다.
	$Panel/CloseButton.pressed.connect(_on_close_button_pressed)
	hide_screen() # 기본적으로는 숨겨진 상태로 시작합니다.

# =============================================================================
# 공개 함수 (Public Methods)
# =============================================================================

func show_screen():
	print("InventoryScreen: 화면 표시")
	self.visible = true
	# TODO: 플레이어의 실제 인벤토리 데이터를 기반으로 격자 UI를 그리는 로직 구현 (테트리스 로직 포함)

func hide_screen():
	print("InventoryScreen: 화면 숨김")
	self.visible = false

# =============================================================================
# 시그널 핸들러 (Signal Handlers)
# =============================================================================

func _on_close_button_pressed():
	# 닫기 버튼이 눌리면 화면을 숨기고 시그널을 보냅니다.
	hide_screen()
	emit_signal("inventory_closed")

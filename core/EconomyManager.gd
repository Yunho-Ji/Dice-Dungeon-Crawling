extends Node

# EconomyManager
# 역할: 재화(Gold) 관리, 상점, 경제 밸런싱.

var current_gold: int = 0

func _ready():
	# 초기화 (추후 저장된 데이터 로드 필요)
	pass

# 외부에서 주입하는 골드 검증 로직 (예: 인벤토리 공간 확인)
# func(current_gold: int, projected_gold: int) -> int
var gold_validator: Callable

func get_gold() -> int:
	return current_gold

# 골드 추가/사용
func add_gold(amount: int):
	var projected_gold = current_gold + amount
	var allowed_gold = projected_gold
	
	# 검증 로직이 주입되어 있다면 실행
	if gold_validator.is_valid():
		allowed_gold = gold_validator.call(current_gold, projected_gold)
	
	if allowed_gold != projected_gold:
		var lost = projected_gold - allowed_gold
		print("EconomyManager: [골드 유실] 한도 초과로 ", lost, "G가 증발했습니다!")
	
	_set_gold(allowed_gold)

func spend_gold(amount: int) -> bool:
	if current_gold >= amount:
		_set_gold(current_gold - amount)
		return true
	return false

func has_gold(amount: int) -> bool:
	return current_gold >= amount

# 골드 강제 설정 (로드 및 초기화용)
func set_gold(amount: int):
	_set_gold(amount)

# 내부적으로 골드 설정 및 시그널 발생
func _set_gold(new_amount: int):
	var delta = new_amount - current_gold
	current_gold = new_amount
	
	print("EconomyManager: Gold Updated -> ", current_gold, " (Delta: ", delta, ")")
	
	# 전역 이벤트 발생
	SignalBus.emit_signal("gold_changed", current_gold, delta)

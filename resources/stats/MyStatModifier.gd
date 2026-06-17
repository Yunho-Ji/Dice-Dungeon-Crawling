extends Resource
class_name MyStatModifier

enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	SET # Set value directly, ignoring base_value
}

# [신규] 스탯 보너스의 출처 정의 (리팩토링 핵심)
enum Source {
	EQUIPMENT,  # 장비 아이템
	GROWTH,     # 주사위 성장 (운명 설계)
	GLOBAL,     # 전역 강화 (기도원 공물 등)
	STATUS,     # 상태 효과 (버프/디버프)
	PASSIVE     # 고유 패시브 및 특성
}

var operation: Operation = Operation.ADD
var value: Variant = 0
var target_stat_key: String = "" # 이 수정자가 적용될 스탯의 키 (예: "vit", "atk") 
var source: Source = Source.EQUIPMENT # 기본값은 장비로 설정

func apply(current_value: Variant) -> Variant:
	match operation:
		Operation.ADD:
			return current_value + value
		Operation.SUBTRACT:
			return current_value - value
		Operation.MULTIPLY:
			return current_value * value
		Operation.DIVIDE:
			if value == 0:
				push_error("MyStatModifier: Cannot divide by zero!")
				return current_value
			return current_value / value
		Operation.SET:
			return value
	return current_value
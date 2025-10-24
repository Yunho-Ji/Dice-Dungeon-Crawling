extends Resource
class_name MyStatModifier

enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	SET # Set value directly, ignoring base_value
}

var operation: Operation = Operation.ADD
var value: Variant = 0
var target_stat_key: String = "" # 이 수정자가 적용될 스탯의 키 (예: "health", "attack_power")

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
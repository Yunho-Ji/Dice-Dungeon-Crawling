# AdvantageLabel.gd
# 설명: '어드밴티지' 효과 하나를 표시하는 UI 요소입니다.
# 마우스를 올리면 상세 설명을 보여주는 기능을 가집니다.
extends Label

# =============================================================================
# 변수 (Variables)
# =============================================================================

# 이 라벨이 표시할 어드밴티지의 이름과 상세 설명입니다.
var advantage_name: String = "어드밴티지"
var advantage_description: String = "상세 설명"

# =============================================================================
# Godot 내장 함수 (Built-in Godot Functions)
# =============================================================================

func _ready():
	# 마우스 이벤트를 감지하기 위해 설정합니다.
	mouse_filter = MOUSE_FILTER_PASS
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	
	# 초기 텍스트를 설정합니다.
	update_text()

# =============================================================================
# 공개 함수 (Public Methods)
# =============================================================================

# 어드밴티지 정보를 설정하고 텍스트를 업데이트하는 함수입니다.
func set_advantage(p_name: String, description: String):
	advantage_name = p_name
	advantage_description = description
	update_text()

# 라벨의 기본 텍스트를 업데이트합니다.
func update_text():
	self.text = "- " + advantage_name

# =============================================================================
# 시그널 핸들러 (Signal Handlers)
# =============================================================================

# 마우스가 라벨 위로 올라왔을 때 호출됩니다.
func _on_mouse_entered():
	# Godot의 기본 툴팁 기능을 사용하여 상세 설명을 표시합니다.
	self.tooltip_text = advantage_description

func _on_mouse_exited():
	# 마우스가 라벨을 벗어나면 툴팁은 자동으로 사라집니다.
	pass

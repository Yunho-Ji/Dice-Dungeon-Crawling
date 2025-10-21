extends Resource
class_name StatusEffectData

@export var effect_name: String = ""
@export var duration: float = 0.0 # 0 means infinite duration
@export var modifiers: Array[MyStatModifier] = []
@export var icon_path: String = "" # UI 표시용 아이콘 경로
@export var description: String = "" # UI 표시용 설명

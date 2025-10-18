
extends Resource
class_name DungeonNode

@export var node_id: String
@export var node_type: String # "start", "battle", "elite", "boss", "shop", "rest"
@export var depth: int
@export var next_node_ids: Array[String]
@export var position: Vector2 # Keep position for layout calculation

func _init(p_id: String = "", p_type: String = "battle", p_depth: int = 0, p_position: Vector2 = Vector2.ZERO):
    node_id = p_id
    node_type = p_type
    depth = p_depth
    position = p_position
    next_node_ids = []
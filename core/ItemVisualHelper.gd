extends Node
class_name ItemVisualHelper

# 64x64 기준 (32x32 4칸이 합쳐진 형태)
const CELL_SIZE: int = 64
const SHEET_WIDTH: int = 1024
const COLUMNS: int = SHEET_WIDTH / CELL_SIZE # 1024 / 64 = 16 columns

## 아이템의 아틀라스 인덱스를 받아 Sprite2D 또는 TextureRect의 Region을 설정합니다.
static func apply_atlas_icon(node: Node, index: int):
	var x = (index % COLUMNS) * CELL_SIZE
	var y = (index / COLUMNS) * CELL_SIZE
	var rect = Rect2(x, y, CELL_SIZE, CELL_SIZE)
	
	if node is Sprite2D:
		node.region_enabled = true
		node.region_rect = rect
	elif node is TextureRect:
		# TextureRect는 AtlasTexture를 사용하여 특정 영역만 표시합니다.
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = load("res://resources/items/test bulid2.png")
		atlas_tex.region = rect
		node.texture = atlas_tex

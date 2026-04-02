extends Node2D

## 가로 32 × 세로 32 타일 한 덩어리. 글로벌 타일 행 ty = chunk_index_y * HEIGHT_TILES + local_y.

const TILE_SIZE_PX := 32
const WIDTH_TILES := 32
const HEIGHT_TILES := 32

@export var chunk_index_y: int = 0

@onready var m_tile_layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	_fill_tiles()


func _fill_tiles() -> void:
	for x in range(WIDTH_TILES):
		for y in range(HEIGHT_TILES):
			var global_ty := chunk_index_y * HEIGHT_TILES + y
			var atlas := WorldGenerator.atlas_for_cell(x, global_ty)
			m_tile_layer.set_cell(Vector2i(x, y), 0, atlas)

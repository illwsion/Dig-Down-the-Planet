extends Node2D

## 가로 32 × 세로 32 타일 한 덩어리. 글로벌 타일 행 ty = chunk_index_y * HEIGHT_TILES + local_y.

const TILE_SIZE_PX := 32
const WIDTH_TILES := 32
const HEIGHT_TILES := 32

@export var chunk_index_y: int = 0

@onready var m_tile_layer: TileMapLayer = $TileMapLayer
@onready var m_colliders_root: Node2D = $Colliders

var m_tile_bodies: Dictionary = {} ## Vector2i(local_x, local_y) -> StaticBody2D


func _ready() -> void:
	_fill_tiles()


func has_mineable_tile_at(local_cell: Vector2i) -> bool:
	## 타일이 있는 셀만 채굴 대상(3-5에서 내구도>0로 좁힐 예정).
	return m_tile_layer.get_cell_tile_data(local_cell) != null


func _fill_tiles() -> void:
	# 청크가 다시 생성될 경우를 대비해 기존 충돌을 정리
	for child in m_colliders_root.get_children():
		child.queue_free()
	m_tile_bodies.clear()

	for x in range(WIDTH_TILES):
		for y in range(HEIGHT_TILES):
			var global_ty := chunk_index_y * HEIGHT_TILES + y
			var atlas := WorldGenerator.atlas_for_cell(x, global_ty)
			m_tile_layer.set_cell(Vector2i(x, y), 0, atlas)

			# MVP용 충돌: 각 타일 셀을 고정 사각형(32x32)으로 막아 이동이 타일에 걸리는지 확인
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 1
			body.position = Vector2(x * TILE_SIZE_PX + TILE_SIZE_PX / 2.0, y * TILE_SIZE_PX + TILE_SIZE_PX / 2.0)

			var shape := RectangleShape2D.new()
			shape.size = Vector2(TILE_SIZE_PX, TILE_SIZE_PX)

			var col := CollisionShape2D.new()
			col.shape = shape
			body.add_child(col)
			m_colliders_root.add_child(body)

			m_tile_bodies[Vector2i(x, y)] = body

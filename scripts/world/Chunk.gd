extends Node2D

## 가로 32 × 세로 32 타일 한 덩어리. 글로벌 타일 행 ty = chunk_index_y * HEIGHT_TILES + local_y.

const TILE_SIZE_PX := 32
const WIDTH_TILES := 32
const HEIGHT_TILES := 32

@export var chunk_index_y: int = 0
@export var block_table: BlockTable

@onready var m_tile_layer: TileMapLayer = $TileMapLayer
@onready var m_damage_overlay: Node2D = $DamageOverlay
@onready var m_colliders_root: Node2D = $Colliders

var m_tile_bodies: Dictionary = {} ## Vector2i(local_x, local_y) -> StaticBody2D
## 로컬 셀 → 현재 HP. 스폰 시 솔리드 타일마다 풀 HP로 전부 채움 (3-4).
var m_cell_hp: Dictionary = {}
## 셀별 손상 오버레이(Polygon2D). 타일맵 modulate와 무관하게 셀 단위로만 표시 (3-6).
var m_damage_polys: Dictionary = {} ## Vector2i -> Polygon2D


func _ready() -> void:
	if block_table == null:
		block_table = load("res://resources/world/block_table.tres") as BlockTable
	_fill_tiles()


func block_id_for_cell(_local_cell: Vector2i) -> StringName:
	## 나중에 아틀라스/소스로 돌·흙 분기. MVP는 흙만.
	return &"dirt"


func get_cell_hp(local_cell: Vector2i) -> int:
	return int(m_cell_hp.get(local_cell, 0))


func has_mineable_tile_at(local_cell: Vector2i) -> bool:
	if m_tile_layer.get_cell_tile_data(local_cell) == null:
		return false
	return get_cell_hp(local_cell) > 0


func apply_damage_at_local_if_mineable(local_cell: Vector2i, damage: float) -> void:
	if not has_mineable_tile_at(local_cell):
		return
	var hp: int = get_cell_hp(local_cell)
	var dmg: int = int(round(damage))
	var new_hp: int = maxi(0, hp - dmg)
	if new_hp <= 0:
		_break_cell(local_cell)
	else:
		m_cell_hp[local_cell] = new_hp
		_sync_damage_overlay(local_cell)


func _break_cell(local_cell: Vector2i) -> void:
	## HP 0 — 타일·충돌 제거(3-7에서 자원 훅 추가 예정).
	_remove_damage_overlay(local_cell)
	m_tile_layer.erase_cell(local_cell)
	m_cell_hp.erase(local_cell)
	if m_tile_bodies.has(local_cell):
		var body: Node = m_tile_bodies[local_cell]
		m_tile_bodies.erase(local_cell)
		body.queue_free()


func _clear_damage_overlays() -> void:
	for child in m_damage_overlay.get_children():
		child.queue_free()
	m_damage_polys.clear()


func _remove_damage_overlay(local_cell: Vector2i) -> void:
	if not m_damage_polys.has(local_cell):
		return
	var poly: Node = m_damage_polys[local_cell]
	m_damage_polys.erase(local_cell)
	if is_instance_valid(poly):
		poly.queue_free()


## HP가 깎였을 때만 호출. 풀 HP면 오버레이 제거.
func _sync_damage_overlay(local_cell: Vector2i) -> void:
	if not m_cell_hp.has(local_cell):
		_remove_damage_overlay(local_cell)
		return
	var hp: int = int(m_cell_hp[local_cell])
	var max_hp: int = block_table.get_max_hp(block_id_for_cell(local_cell))
	if max_hp <= 0:
		return
	if hp >= max_hp:
		_remove_damage_overlay(local_cell)
		return
	var damaged: float = 1.0 - float(hp) / float(max_hp)
	var alpha: float = clampf(damaged * 0.7, 0.06, 0.75)
	var col := Color(0.0, 0.0, 0.0, alpha)
	var poly: Polygon2D = m_damage_polys.get(local_cell) as Polygon2D
	if poly == null:
		poly = Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(TILE_SIZE_PX, 0),
			Vector2(TILE_SIZE_PX, TILE_SIZE_PX),
			Vector2(0, TILE_SIZE_PX),
		])
		poly.position = Vector2(float(local_cell.x) * TILE_SIZE_PX, float(local_cell.y) * TILE_SIZE_PX)
		m_damage_overlay.add_child(poly)
		m_damage_polys[local_cell] = poly
	poly.color = col


func _fill_tiles() -> void:
	# 청크가 다시 생성될 경우를 대비해 기존 충돌을 정리
	_clear_damage_overlays()
	for child in m_colliders_root.get_children():
		child.queue_free()
	m_tile_bodies.clear()
	m_cell_hp.clear()

	for x in range(WIDTH_TILES):
		for y in range(HEIGHT_TILES):
			var cell := Vector2i(x, y)
			var global_ty := chunk_index_y * HEIGHT_TILES + y
			var atlas := WorldGenerator.atlas_for_cell(x, global_ty)
			m_tile_layer.set_cell(cell, 0, atlas)

			var bid := block_id_for_cell(cell)
			var max_hp := block_table.get_max_hp(bid)
			m_cell_hp[cell] = max_hp

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

			m_tile_bodies[cell] = body

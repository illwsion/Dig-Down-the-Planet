extends Node2D

## 1-4~2-1: Drill.global_position.y 기준으로 chunk_index_y를 맞춘다. (Main의 Drill 형제)

const CHUNK_SCENE := preload("res://scenes/world/Chunk.tscn")
const CHUNK_WIDTH_TILES := 32
const CHUNK_HEIGHT_TILES := 32
const TILE_SIZE_PX := 32
const CHUNK_HEIGHT_PX := CHUNK_HEIGHT_TILES * TILE_SIZE_PX
const WORLD_ORIGIN_X := -(32 * TILE_SIZE_PX) / 2

## 땅(0m)은 월드 픽셀 y=0부터. 그 위(음수 y 구간)에는 청크를 두지 않음.
const MIN_CHUNK_INDEX_Y := 0

## 카메라가 올라갈 때·내려갈 때 각각 몇 청크까지 미리 유지할지 (타일 단위가 아니라 청크 인덱스)
const CHUNK_MARGIN_ABOVE := 1
const CHUNK_MARGIN_BELOW := 2

var _chunks: Dictionary = {} ## int chunk_index_y -> Node2D (Chunk)

@onready var _focus: Node2D = get_parent().get_node("Drill") as Node2D


func _ready() -> void:
	sync_chunks()


func _process(_delta: float) -> void:
	sync_chunks()


func sync_chunks() -> void:
	if _focus == null:
		return
	var cam_y := _focus.global_position.y
	var focus_cy := int(floor(cam_y / float(CHUNK_HEIGHT_PX)))
	var min_cy: int = maxi(focus_cy - CHUNK_MARGIN_ABOVE, MIN_CHUNK_INDEX_Y)
	var max_cy := focus_cy + CHUNK_MARGIN_BELOW

	for cy in range(min_cy, max_cy + 1):
		if not _chunks.has(cy):
			_spawn_chunk(cy)

	var to_remove: Array[int] = []
	for cy: int in _chunks.keys():
		if cy < MIN_CHUNK_INDEX_Y or cy < min_cy or cy > max_cy:
			to_remove.append(cy)
	for cy in to_remove:
		var node: Node = _chunks[cy]
		_chunks.erase(cy)
		node.queue_free()


func has_mineable_tile_in_circle(center_world: Vector2, radius_px: float) -> bool:
	## tip 기준 원 안에 “타일이 있는 셀”이 하나라도 있으면 true. 타일 AABB와 원 겹침 기준.
	var r2 := radius_px * radius_px
	var ts := float(TILE_SIZE_PX)
	for chunk_node in _chunks.values():
		var chunk: Node2D = chunk_node as Node2D
		if chunk == null or not chunk.has_method("has_mineable_tile_at"):
			continue
		var p_local := chunk.to_local(center_world)
		var min_x := clampi(int(floor((p_local.x - radius_px) / ts)), 0, CHUNK_WIDTH_TILES - 1)
		var max_x := clampi(int(ceil((p_local.x + radius_px) / ts)) - 1, 0, CHUNK_WIDTH_TILES - 1)
		var min_y := clampi(int(floor((p_local.y - radius_px) / ts)), 0, CHUNK_HEIGHT_TILES - 1)
		var max_y := clampi(int(ceil((p_local.y + radius_px) / ts)) - 1, 0, CHUNK_HEIGHT_TILES - 1)
		for ly in range(min_y, max_y + 1):
			for lx in range(min_x, max_x + 1):
				if not _tile_circle_overlap_local(p_local, lx, ly, ts, r2):
					continue
				if chunk.has_mineable_tile_at(Vector2i(lx, ly)):
					return true
	return false


func _tile_circle_overlap_local(p_local: Vector2, lx: int, ly: int, tile_size: float, r2: float) -> bool:
	var left := float(lx) * tile_size
	var right := left + tile_size
	var top := float(ly) * tile_size
	var bottom := top + tile_size
	var qx := clampf(p_local.x, left, right)
	var qy := clampf(p_local.y, top, bottom)
	return p_local.distance_squared_to(Vector2(qx, qy)) <= r2


func get_active_chunk_summary() -> String:
	var keys: Array = _chunks.keys()
	keys.sort()
	if keys.is_empty():
		return "활성 청크: 없음"
	var acc := "활성 청크: "
	for i in range(keys.size()):
		if i > 0:
			acc += ", "
		acc += str(keys[i])
	return acc


func _spawn_chunk(chunk_index_y: int) -> void:
	if chunk_index_y < MIN_CHUNK_INDEX_Y:
		return
	var chunk: Node2D = CHUNK_SCENE.instantiate()
	chunk.chunk_index_y = chunk_index_y
	chunk.position = Vector2(WORLD_ORIGIN_X, chunk_index_y * CHUNK_HEIGHT_PX)
	add_child(chunk)
	_chunks[chunk_index_y] = chunk

extends Node2D

## Chunk 자식. Drill.debug_show_tile_hp 가 true 일 때 타일별 현재 HP를 표시한다.

const TILE_SIZE_PX := 32
const WIDTH_TILES := 32
const HEIGHT_TILES := 32

var m_labels: Dictionary = {} ## Vector2i -> Label
var m_was_visible: bool = false


func _process(_delta: float) -> void:
	var chunk: Node = get_parent()
	if chunk == null:
		return

	var show: bool = _is_debug_enabled()
	if not show:
		if m_was_visible:
			_set_all_visible(false)
			m_was_visible = false
		return

	m_was_visible = true
	for y in range(HEIGHT_TILES):
		for x in range(WIDTH_TILES):
			var cell := Vector2i(x, y)
			if not chunk.has_method("has_mineable_tile_at") or not chunk.has_mineable_tile_at(cell):
				_hide_label(cell)
				continue
			var hp: int = int(chunk.call("get_cell_hp", cell))
			var lbl: Label = _ensure_label(cell)
			lbl.text = str(hp)
			lbl.visible = true


func _is_debug_enabled() -> bool:
	var drill := _find_drill()
	return drill != null and drill.get("debug_show_tile_hp") == true


func _find_drill() -> Node:
	var chunk: Node = get_parent()
	if chunk == null:
		return null
	var world: Node = chunk.get_parent()
	if world == null:
		return null
	var main: Node = world.get_parent()
	if main == null:
		return null
	return main.get_node_or_null("Drill")


func _ensure_label(local_cell: Vector2i) -> Label:
	var lbl: Label = m_labels.get(local_cell) as Label
	if lbl != null:
		return lbl

	lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(
		float(local_cell.x) * TILE_SIZE_PX,
		float(local_cell.y) * TILE_SIZE_PX
	)
	lbl.size = Vector2(TILE_SIZE_PX, TILE_SIZE_PX)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override(&"font_size", 10)
	lbl.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.95))
	lbl.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override(&"outline_size", 2)
	add_child(lbl)
	m_labels[local_cell] = lbl
	return lbl


func _hide_label(local_cell: Vector2i) -> void:
	if not m_labels.has(local_cell):
		return
	var lbl: Label = m_labels[local_cell] as Label
	if is_instance_valid(lbl):
		lbl.visible = false


func _set_all_visible(visible: bool) -> void:
	for lbl: Label in m_labels.values():
		if is_instance_valid(lbl):
			lbl.visible = visible

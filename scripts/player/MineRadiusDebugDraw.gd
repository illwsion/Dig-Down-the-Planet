extends Node2D

## Drill tip(부모 원점) 기준으로 `mine_contact_radius` / `mine_radius` 테두리 원 (3-2).

const CONTACT_COLOR := Color(1.0, 0.82, 0.15, 0.9)
const MINE_COLOR := Color(0.25, 0.95, 1.0, 0.8)
const ARC_POINTS_CONTACT := 40
const ARC_POINTS_MINE := 56
const LINE_WIDTH := 2.0


func _process(_delta: float) -> void:
	# debug off여도 한 번 더 그려야 이전 원이 지워짐
	if get_parent() != null:
		queue_redraw()


func _draw() -> void:
	var p := get_parent()
	if p == null or not p.get("debug_draw_mine_radii"):
		return

	var r_contact: Variant = p.get("mine_contact_radius")
	var r_mine: Variant = p.get("mine_radius")
	if typeof(r_contact) != TYPE_FLOAT and typeof(r_contact) != TYPE_INT:
		return
	if typeof(r_mine) != TYPE_FLOAT and typeof(r_mine) != TYPE_INT:
		return

	var rc := float(r_contact)
	var rm := float(r_mine)
	var center := Vector2.ZERO

	# 안쪽: 접촉, 바깥: 채굴 (겹침이 보이도록 안쪽을 먼저 그림)
	draw_arc(center, rc, 0.0, TAU, ARC_POINTS_CONTACT, CONTACT_COLOR, LINE_WIDTH, true)
	draw_arc(center, rm, 0.0, TAU, ARC_POINTS_MINE, MINE_COLOR, LINE_WIDTH, true)

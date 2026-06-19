class_name RunInventoryPanel
extends PanelContainer

## 런 중 임시 배낭을 16칸 고정 그리드로 표시한다.
## 슬롯 점유/아이콘은 RunInventory 기준, 수량 텍스트는 GameState.run_display 기준으로 표시한다.

const c_TotalSlotCount: int = 16
const c_Columns: int = 4
const c_SlotSize: Vector2 = Vector2(42.0, 42.0)
const c_IconSize: Vector2 = Vector2(30.0, 30.0)

const c_ActiveSlotColor: Color = Color(0.12, 0.12, 0.14, 0.86)
const c_LockedSlotColor: Color = Color(0.04, 0.04, 0.05, 0.78)
const c_ReservedIconAlpha: float = 0.42
const c_VisibleIconAlpha: float = 1.0

var m_title_label: Label
var m_grid: GridContainer
var m_cells: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()


func refresh(_inventory: RunInventory, _display: Dictionary) -> void:
	if _inventory == null:
		return
	if m_cells.is_empty():
		_build_ui()

	var used_slots: int = _count_used_slots(_inventory)
	m_title_label.text = "배낭 %d/%d" % [used_slots, _inventory.slot_count]

	var display_remaining: Dictionary = _display.duplicate()
	for i in c_TotalSlotCount:
		var is_unlocked: bool = i < _inventory.slot_count
		var slot: Dictionary = _get_slot_or_empty(_inventory, i)
		var item_id: StringName = slot["item_id"]
		var actual_count: int = int(slot["count"])
		var shown_count: int = _consume_display_count(display_remaining, item_id, actual_count)
		_render_cell(i, is_unlocked, item_id, actual_count, shown_count)


func _build_ui() -> void:
	if m_grid != null:
		return

	custom_minimum_size = Vector2(204.0, 232.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _make_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	m_title_label = Label.new()
	m_title_label.text = "배낭 0/0"
	m_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_title_label.add_theme_font_size_override("font_size", 16)
	content.add_child(m_title_label)

	m_grid = GridContainer.new()
	m_grid.columns = c_Columns
	m_grid.add_theme_constant_override("h_separation", 6)
	m_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(m_grid)

	for i in c_TotalSlotCount:
		m_cells.append(_create_cell())


func _create_cell() -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = c_SlotSize
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", _make_slot_style(c_ActiveSlotColor))
	m_grid.add_child(root)

	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack)

	var icon := TextureRect.new()
	icon.custom_minimum_size = c_IconSize
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -c_IconSize.x * 0.5
	icon.offset_top = -c_IconSize.y * 0.5
	icon.offset_right = c_IconSize.x * 0.5
	icon.offset_bottom = c_IconSize.y * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)

	var count_label := Label.new()
	count_label.anchor_left = 0.0
	count_label.anchor_top = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = 2.0
	count_label.offset_top = -18.0
	count_label.offset_right = -3.0
	count_label.offset_bottom = -1.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(count_label)

	var lock_label := Label.new()
	lock_label.anchor_right = 1.0
	lock_label.anchor_bottom = 1.0
	lock_label.text = "LOCK"
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_label.add_theme_font_size_override("font_size", 10)
	lock_label.modulate = Color(1.0, 1.0, 1.0, 0.45)
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(lock_label)

	return {
		"root": root,
		"icon": icon,
		"count_label": count_label,
		"lock_label": lock_label,
	}


func _render_cell(_index: int, _is_unlocked: bool, _item_id: StringName, _actual_count: int, _shown_count: int) -> void:
	var cell: Dictionary = m_cells[_index]
	var root: PanelContainer = cell["root"]
	var icon: TextureRect = cell["icon"]
	var count_label: Label = cell["count_label"]
	var lock_label: Label = cell["lock_label"]

	root.add_theme_stylebox_override("panel", _make_slot_style(c_ActiveSlotColor if _is_unlocked else c_LockedSlotColor))
	lock_label.visible = not _is_unlocked
	icon.visible = _is_unlocked and _item_id != &"" and _actual_count > 0
	count_label.visible = false

	if not icon.visible:
		icon.texture = null
		return

	var def: ItemDef = ItemDatabase.get_def(_item_id)
	icon.texture = def.icon if def != null else null
	icon.modulate.a = c_VisibleIconAlpha if _shown_count > 0 else c_ReservedIconAlpha

	if _shown_count > 0:
		count_label.text = str(_shown_count)
		count_label.visible = true


func _consume_display_count(_display_remaining: Dictionary, _item_id: StringName, _actual_count: int) -> int:
	if _item_id == &"" or _actual_count <= 0:
		return 0
	var remaining: int = int(_display_remaining.get(_item_id, 0))
	if remaining <= 0:
		return 0
	var shown: int = mini(remaining, _actual_count)
	_display_remaining[_item_id] = remaining - shown
	return shown


func _get_slot_or_empty(_inventory: RunInventory, _index: int) -> Dictionary:
	if _index >= 0 and _index < _inventory.slots.size():
		return _inventory.slots[_index]
	return {"item_id": &"", "count": 0}


func _count_used_slots(_inventory: RunInventory) -> int:
	var count: int = 0
	for slot in _inventory.slots:
		if slot["item_id"] != &"":
			count += 1
	return count


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.025, 0.62)
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _make_slot_style(_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color
	style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style

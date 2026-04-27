extends Control

const c_ZoomMin := 0.3
const c_ZoomMax := 2.0
const c_ZoomStep := 0.1

@onready var m_canvas: Node2D = $Canvas
@onready var m_connections_layer: Node2D = $Canvas/ConnectionsLayer
@onready var m_nodes_layer: Control = $Canvas/NodesLayer
@onready var m_tooltip: Node = $Tooltip

var m_is_dragging: bool = false


func _ready() -> void:
	_setup_skill_nodes()
	refresh()
	GameState.dollars_changed.connect(_refresh_colors)
	GameState.hub_inventory.inventory_changed.connect(_refresh_colors)


func refresh(_reset_position: bool = false) -> void:
	if _reset_position:
		m_canvas.position = size / 2.0
		m_canvas.scale = Vector2.ONE
	for node in m_nodes_layer.get_children():
		node.visible = GameState.visible_skills.has(node.m_skill_id)
		node.update_color()
	m_connections_layer.queue_redraw()


func _on_skill_purchased(_skillId: StringName) -> void:
	_check_new_unlocks()
	call_deferred("refresh")


func _gui_input(_event: InputEvent) -> void:
	if _event is InputEventMouseButton:
		if _event.button_index == MOUSE_BUTTON_LEFT:
			m_is_dragging = _event.pressed

		elif _event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(_event.position, 1.0 + c_ZoomStep)

		elif _event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(_event.position, 1.0 - c_ZoomStep)

	elif _event is InputEventMouseMotion and m_is_dragging:
		m_canvas.position += _event.relative


func _zoom(_mousePos: Vector2, _factor: float) -> void:
	var oldScale := m_canvas.scale.x
	var newScale := clampf(oldScale * _factor, c_ZoomMin, c_ZoomMax)
	var actualFactor := newScale / oldScale
	m_canvas.position = _mousePos + (m_canvas.position - _mousePos) * actualFactor
	m_canvas.scale = Vector2(newScale, newScale)


func _setup_skill_nodes() -> void:
	for node in m_nodes_layer.get_children():
		node.setup(m_tooltip)
		node.purchased.connect(_on_skill_purchased)


func _check_new_unlocks() -> void:
	for skillNode in m_nodes_layer.get_children():
		if GameState.visible_skills.has(skillNode.m_skill_id):
			continue
		var allMet := true
		for nodePath in skillNode.m_prerequisite_nodes:
			var prereqNode := skillNode.get_node(nodePath)
			if GameState.learned_skills.get(prereqNode.m_skill_id, 0) < 1:
				allMet = false
				break
		if allMet:
			GameState.visible_skills.append(skillNode.m_skill_id)


func _refresh_colors() -> void:
	for child in m_nodes_layer.get_children():
		child.update_color()

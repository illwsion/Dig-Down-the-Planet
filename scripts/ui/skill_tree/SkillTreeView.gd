extends Control

const c_SkillNodeScene := preload("res://scenes/ui/skill_tree/SkillNode.tscn")
const c_ZoomMin := 0.3
const c_ZoomMax := 2.0
const c_ZoomStep := 0.1

@onready var m_canvas: Node2D = $Canvas
@onready var m_connections_layer: Node2D = $Canvas/ConnectionsLayer
@onready var m_nodes_layer: Control = $Canvas/NodesLayer
@onready var m_tooltip: Node = $Tooltip

var m_skill_defs: Dictionary = {}
var m_is_dragging: bool = false


func _ready() -> void:
	_load_skill_defs()
	refresh()


func refresh() -> void:
	m_canvas.position = size / 2.0
	_clear_nodes()
	for skillId in GameState.visible_skills:
		if not m_skill_defs.has(skillId):
			push_warning("SkillTreeView: 스킬 id를 찾을 수 없음 — %s" % skillId)
			continue
		var skillDef: SkillDef = m_skill_defs[skillId]
		var currentLevel: int = GameState.learned_skills.get(skillId, 0)
		var node := c_SkillNodeScene.instantiate()
		m_nodes_layer.add_child(node)
		node.setup(skillDef, currentLevel, m_tooltip)
		node.purchased.connect(_on_skill_purchased)

	m_connections_layer.update_lines(m_skill_defs)
	print("SkillTreeView: %d개 스킬 노드 배치 완료" % m_nodes_layer.get_child_count())


func _on_skill_purchased(_skillId: StringName) -> void:
	var skillDef: SkillDef = m_skill_defs.get(_skillId)
	if not skillDef:
		return

	var newLevel: int = GameState.learned_skills.get(_skillId, 0)
	if newLevel == 1:
		for unlockedId in skillDef.unlocks:
			if GameState.visible_skills.has(unlockedId):
				continue
			var unlockedDef: SkillDef = m_skill_defs.get(unlockedId)
			if not unlockedDef:
				continue
			var allMet := true
			for prereqId in unlockedDef.prerequisites:
				if GameState.learned_skills.get(prereqId, 0) < 1:
					allMet = false
					break
			if allMet:
				GameState.visible_skills.append(unlockedId)

	refresh()


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


func _load_skill_defs() -> void:
	var allSkills := SkillDatabase.load_all()
	for skillDef in allSkills:
		m_skill_defs[skillDef.id] = skillDef
	print("SkillTreeView: 스킬 데이터 %d개 로드 완료" % m_skill_defs.size())


func _clear_nodes() -> void:
	for child in m_nodes_layer.get_children():
		child.queue_free()

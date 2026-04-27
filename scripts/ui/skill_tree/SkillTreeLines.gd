@tool
extends Node2D

const c_ColorConnected := Color(1.0, 1.0, 1.0, 0.9)
const c_ColorUnlearned := Color(0.5, 0.5, 0.5, 0.6)
const c_LineWidth := 2.0

@onready var m_nodes_layer: Control = $"../NodesLayer"


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if m_nodes_layer == null:
		return

	if Engine.is_editor_hint():
		for skillNode in m_nodes_layer.get_children():
			for prereqPath in skillNode.m_prerequisite_nodes:
				var prereqNode := skillNode.get_node_or_null(prereqPath)
				if prereqNode == null:
					continue
				var fromPos: Vector2 = prereqNode.position + prereqNode.size / 2.0
				var toPos: Vector2 = skillNode.position + skillNode.size / 2.0
				draw_line(fromPos, toPos, c_ColorConnected, c_LineWidth)
	else:
		for skillNode in m_nodes_layer.get_children():
			if not skillNode.visible:
				continue
			for prereqPath in skillNode.m_prerequisite_nodes:
				var prereqNode := skillNode.get_node(prereqPath)
				if not prereqNode.visible:
					continue
				var prereqLearned: bool = GameState.learned_skills.get(prereqNode.m_skill_id, 0) >= 1
				var lineColor := c_ColorConnected if prereqLearned else c_ColorUnlearned
				var fromPos: Vector2 = prereqNode.position + prereqNode.size / 2.0
				var toPos: Vector2 = skillNode.position + skillNode.size / 2.0
				draw_line(fromPos, toPos, lineColor, c_LineWidth)

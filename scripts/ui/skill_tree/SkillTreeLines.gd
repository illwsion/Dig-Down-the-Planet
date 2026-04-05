extends Node2D

const c_ColorConnected := Color(1.0, 1.0, 1.0, 0.9)
const c_ColorUnlearned := Color(0.5, 0.5, 0.5, 0.6)
const c_LineWidth := 2.0

var m_skill_defs: Dictionary = {}


func update_lines(_skillDefs: Dictionary) -> void:
	m_skill_defs = _skillDefs
	queue_redraw()


func _draw() -> void:
	for skillId in GameState.visible_skills:
		var skillDef: SkillDef = m_skill_defs.get(skillId)
		if not skillDef:
			continue
		for prereqId in skillDef.prerequisites:
			if not GameState.visible_skills.has(prereqId):
				continue
			var prereqDef: SkillDef = m_skill_defs.get(prereqId)
			if not prereqDef:
				continue
			var prereqLearned: bool = (GameState.learned_skills.get(prereqId, 0) as int) >= 1
			var lineColor := c_ColorConnected if prereqLearned else c_ColorUnlearned
			draw_line(prereqDef.position, skillDef.position, lineColor, c_LineWidth)

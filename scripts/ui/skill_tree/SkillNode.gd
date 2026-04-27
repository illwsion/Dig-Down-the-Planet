extends TextureButton

const c_ColorCanAfford := Color(0.5, 1.0, 0.5)
const c_ColorCannotAfford := Color(1.0, 0.5, 0.5)
const c_ColorMaxLevel := Color(0.55, 0.55, 0.55)

@export var m_skill_id: StringName
@export var m_prerequisite_nodes: Array[NodePath]

var m_skill_def: SkillDef
var m_current_level: int:
	get: return GameState.learned_skills.get(m_skill_id, 0)
var m_tooltip: Node

signal purchased(skill_id: StringName)


func setup(_tooltip: Node) -> void:
	m_tooltip = _tooltip
	m_skill_def = SkillDatabase.find_by_id(m_skill_id)
	if m_skill_def == null:
		push_error("SkillNode: skill_id를 찾을 수 없음 — %s" % m_skill_id)
		return
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)
	update_color()


func _on_mouse_entered() -> void:
	if m_tooltip:
		m_tooltip.show_for(m_skill_def, m_current_level)


func _on_mouse_exited() -> void:
	if m_tooltip:
		m_tooltip.visible = false


func _on_pressed() -> void:
	if m_current_level >= m_skill_def.max_level:
		return

	var cost: SkillCost = m_skill_def.cost_per_level[m_current_level]
	if not GameState.can_afford(cost):
		return

	GameState.deduct_cost(cost)
	GameState.learned_skills[m_skill_def.id] = m_current_level + 1
	if m_tooltip and m_tooltip.visible:
		m_tooltip.show_for(m_skill_def, m_current_level)
	purchased.emit(m_skill_def.id)


func update_color() -> void:
	if m_skill_def == null:
		return
	if m_current_level >= m_skill_def.max_level:
		modulate = c_ColorMaxLevel
		return
	var cost: SkillCost = m_skill_def.cost_per_level[m_current_level]
	modulate = c_ColorCanAfford if GameState.can_afford(cost) else c_ColorCannotAfford

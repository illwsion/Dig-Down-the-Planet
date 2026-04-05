extends Control

const c_DefaultIcon := preload("res://icon.svg")
const c_ColorCanAfford := Color(0.5, 1.0, 0.5)
const c_ColorCannotAfford := Color(1.0, 0.5, 0.5)
const c_ColorMaxLevel := Color(0.55, 0.55, 0.55)

@onready var m_icon_button: TextureButton = $IconButton

var m_skill_def: SkillDef
var m_current_level: int
var m_tooltip: Node

signal purchased(skill_id: StringName)


func setup(_skillDef: SkillDef, _currentLevel: int, _tooltip: Node) -> void:
	m_skill_def = _skillDef
	m_current_level = _currentLevel
	m_tooltip = _tooltip
	position = _skillDef.position - custom_minimum_size / 2.0
	m_icon_button.texture_normal = c_DefaultIcon
	m_icon_button.mouse_entered.connect(_on_mouse_entered)
	m_icon_button.mouse_exited.connect(_on_mouse_exited)
	m_icon_button.pressed.connect(_on_pressed)
	_update_color()


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
	purchased.emit(m_skill_def.id)


func _update_color() -> void:
	if m_current_level >= m_skill_def.max_level:
		m_icon_button.modulate = c_ColorMaxLevel
		return
	var cost: SkillCost = m_skill_def.cost_per_level[m_current_level]
	m_icon_button.modulate = c_ColorCanAfford if GameState.can_afford(cost) else c_ColorCannotAfford

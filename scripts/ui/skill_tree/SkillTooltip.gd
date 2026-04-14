extends PanelContainer

@onready var m_name_label: Label = $MarginContainer/VBox/HeaderRow/NameLabel
@onready var m_level_label: Label = $MarginContainer/VBox/HeaderRow/LevelLabel
@onready var m_desc_label: Label = $MarginContainer/VBox/DescLabel
@onready var m_cost_label: Label = $MarginContainer/VBox/CostLabel
@onready var m_separator_cost: HSeparator = $MarginContainer/VBox/SeparatorCost
@onready var m_separator_effects: HSeparator = $MarginContainer/VBox/SeparatorEffects
@onready var m_effects_box: VBoxContainer = $MarginContainer/VBox/EffectsBox
@onready var m_max_level_label: Label = $MarginContainer/VBox/MaxLevelLabel

const c_Offset := Vector2(12, 12)
const c_ScreenMargin := 8.0


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_position(get_viewport().get_mouse_position())


func show_for(_skillDef: SkillDef, _currentLevel: int) -> void:
	m_name_label.text = _skillDef.display_name
	m_level_label.text = "%d / %d" % [_currentLevel, _skillDef.max_level]
	m_desc_label.text = _skillDef.description

	var isMaxLevel := _currentLevel >= _skillDef.max_level

	_update_cost(_skillDef, _currentLevel, isMaxLevel)
	_update_effects(_skillDef, _currentLevel, isMaxLevel)

	visible = true


func _update_cost(_skillDef: SkillDef, _currentLevel: int, _isMaxLevel: bool) -> void:
	if _isMaxLevel:
		m_separator_cost.visible = false
		m_cost_label.visible = false
		return

	m_separator_cost.visible = true
	m_cost_label.visible = true

	var cost: SkillCost = _skillDef.cost_per_level[_currentLevel]
	var parts: Array[String] = []

	if cost.dollar_cost > 0:
		parts.append("$%d" % cost.dollar_cost)

	for oreId in cost.ore_costs:
		parts.append("%s × %d" % [oreId, cost.ore_costs[oreId]])

	m_cost_label.text = "비용: %s" % (", ".join(parts) if parts.size() > 0 else "없음")


func _update_effects(_skillDef: SkillDef, _currentLevel: int, _isMaxLevel: bool) -> void:
	for child in m_effects_box.get_children():
		child.queue_free()

	if _isMaxLevel:
		m_separator_effects.visible = false
		m_effects_box.visible = false
		m_max_level_label.visible = true
		return

	m_separator_effects.visible = true
	m_effects_box.visible = true
	m_max_level_label.visible = false

	for effect in _skillDef.effects:
		var currentFinal := StatSystem.get_final(effect.stat_id)
		var nextFinal    := currentFinal + effect.value_per_level
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 13)
		row.text = "%s  %s → %s" % [
			effect.stat_id,
			_format_number(currentFinal),
			_format_number(nextFinal)
		]
		m_effects_box.add_child(row)


func _update_position(_mousePos: Vector2) -> void:
	var viewportSize := get_viewport_rect().size
	var tooltipSize := size
	var targetPos := _mousePos + c_Offset

	if targetPos.x + tooltipSize.x + c_ScreenMargin > viewportSize.x:
		targetPos.x = _mousePos.x - tooltipSize.x - c_Offset.x

	if targetPos.y + tooltipSize.y + c_ScreenMargin > viewportSize.y:
		targetPos.y = _mousePos.y - tooltipSize.y - c_Offset.y

	global_position = targetPos


func _format_number(_value: float) -> String:
	if _value == floorf(_value):
		return str(int(_value))
	return "%.1f" % _value

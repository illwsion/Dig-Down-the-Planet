class_name SkillDatabase

## CSV에서 스킬 데이터를 로드해 SkillDef 배열로 반환하는 정적 유틸리티.
##
## CSV 컬럼 순서 (0-based):
##  0  id
##  1  icon_id             (비어 있으면 id와 동일. SkillIcons 조회 키)
##  2  display_name
##  3  description
##  4  max_level
##  5  dollar_cost_base    (1레벨 달러 비용)
##  6  dollar_cost_growth  (레벨당 달러 증가량)
##  7  ore_id              (없으면 빈 문자열)
##  8  ore_amount_base     (1레벨 광석 비용)
##  9  ore_amount_growth   (레벨당 광석 증가량)
##  10 effect_1_stat
##  11 effect_1_value
##  12 effect_2_stat
##  13 effect_2_value
##  14 effect_3_stat
##  15 effect_3_value
##
## prerequisites, unlocks, pos_x, pos_y는 skill_tree.tscn의 SkillNode가 담당한다.
## 레벨 N 비용 공식:
##   dollar  = dollar_cost_base  + dollar_cost_growth  × (N - 1)
##   ore     = ore_amount_base   + ore_amount_growth   × (N - 1)

const c_CsvPath := "res://resources/skills/skill_database.csv"
const c_MaxEffects := 3
const c_TotalColumns := 16


static func load_all() -> Array[SkillDef]:
	var skills: Array[SkillDef] = []

	var file := FileAccess.open(c_CsvPath, FileAccess.READ)
	if file == null:
		push_error("SkillDatabase: CSV를 찾을 수 없음 — " + c_CsvPath)
		return skills

	file.get_csv_line()

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		var skill := _parse_row(row)
		if skill != null:
			skills.append(skill)

	return skills


static func _parse_row(_row: PackedStringArray) -> SkillDef:
	if _row.size() < c_TotalColumns:
		push_warning("SkillDatabase: 컬럼 수 부족 (%d개), 건너뜀 — %s" % [_row.size(), str(_row)])
		return null

	var skill := SkillDef.new()
	skill.id           = StringName(_row[0].strip_edges())
	skill.icon_id      = StringName(_row[1].strip_edges())
	skill.display_name = _row[2].strip_edges()
	skill.description  = _row[3].strip_edges()
	skill.max_level    = int(_row[4].strip_edges())

	var dollarBase   := int(_row[5].strip_edges())
	var dollarGrowth := int(_row[6].strip_edges())
	var oreId        := _row[7].strip_edges()
	var oreBase      := int(_row[8].strip_edges())
	var oreGrowth    := int(_row[9].strip_edges())

	for level in range(1, skill.max_level + 1):
		var cost := SkillCost.new()
		cost.dollar_cost = dollarBase + dollarGrowth * (level - 1)
		if not oreId.is_empty() and (oreBase + oreGrowth * (level - 1)) > 0:
			cost.ore_costs[StringName(oreId)] = oreBase + oreGrowth * (level - 1)
		skill.cost_per_level.append(cost)

	for i in c_MaxEffects:
		var statCol  := 10 + i * 2
		var valueCol := 11 + i * 2
		var statId := _row[statCol].strip_edges()
		if statId.is_empty():
			continue
		var effect := SkillEffect.new()
		effect.stat_id         = StringName(statId)
		effect.value_per_level = float(_row[valueCol].strip_edges())
		skill.effects.append(effect)

	var lookupId: StringName = skill.icon_id if skill.icon_id != &"" else skill.id
	var icon: Texture2D = SkillIcons.get_icon(lookupId)
	if icon != null:
		skill.icon = icon
	elif lookupId != &"":
		push_warning("SkillDatabase: 알 수 없는 icon_id '%s' (skill '%s')" % [lookupId, skill.id])

	return skill


static func find_by_id(_id: StringName) -> SkillDef:
	for skill in load_all():
		if skill.id == _id:
			return skill
	return null

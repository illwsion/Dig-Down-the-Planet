extends Node

## 스킬 효과를 게임플레이 수치에 반영하는 중간 계층.
## 각 스탯의 기본값(base)을 보관하고, GameState.learned_skills를 기반으로
## 모든 스킬 보너스를 합산한 최종값을 제공한다.
##
## 최종값 = 기본값 + Σ(value_per_level × current_level)  [해당 stat_id 스킬 효과 전체 합산]

## { stat_id: StringName → base: float }
## Drill.gd._ready() 이전(Hub 화면)에도 툴팁이 올바른 수치를 보여줄 수 있도록
## Drill.gd의 @export 기본값과 동일한 값으로 미리 선언해둔다.
var m_bases: Dictionary = {}

## SkillDatabase.load_all() 결과 캐시. get_final() 최초 호출 시 lazy load.
var m_skill_defs: Array[SkillDef] = []
var m_skill_defs_loaded: bool = false


func get_final(_stat_id: StringName) -> float:
	_ensure_skill_defs_loaded()
	var base: float = m_bases.get(_stat_id, 0.0)
	var bonus: float = 0.0
	for skillDef in m_skill_defs:
		var level: int = GameState.learned_skills.get(skillDef.id, 0)
		if level <= 0:
			continue
		for effect in skillDef.effects:
			if effect.stat_id == _stat_id:
				bonus += effect.value_per_level * level
	return base + bonus


## Drill._ready()에서 호출. 인스펙터 설정값으로 하드코딩 기본값을 덮어씌운다.
func register_base(_stat_id: StringName, _value: float) -> void:
	m_bases[_stat_id] = _value


func _ensure_skill_defs_loaded() -> void:
	if m_skill_defs_loaded:
		return
	m_skill_defs = SkillDatabase.load_all()
	m_skill_defs_loaded = true


func _ready() -> void:
	m_bases = {
		&"mine_damage_per_tick":     1.0,
		&"mine_radius":              50.0,
		&"mine_contact_radius":      10.0,
		&"mine_tick_interval":       1.0,
		&"move_speed_max":           400.0,
		&"move_acceleration":        400.0,
		&"aim_angle_limit_deg":      30.0,
		&"aim_turn_max_deg_per_sec": 54.0,
		&"fuel_max":                 100.0,
		&"fuel_drain_per_second":    5.0,
	}

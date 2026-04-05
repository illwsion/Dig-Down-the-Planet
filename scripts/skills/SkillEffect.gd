class_name SkillEffect
extends Resource

## 스킬 하나가 적용하는 단일 스탯 효과.
## 최종값 = 기본값 + (value_per_level × current_level)

var stat_id: StringName
var value_per_level: float

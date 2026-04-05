class_name SkillCost
extends Resource

## 스킬 레벨 하나를 올리는 데 필요한 비용.
## dollar_cost 는 달러 시스템 구현 전까지 0으로 고정.
## ore_costs 는 { ore_id: StringName -> amount: int } 형태.

var dollar_cost: int = 0
var ore_costs: Dictionary = {}

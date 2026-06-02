class_name FuelDepthCost
extends RefCounted

## 깊이(m)에 따른 틱당 연료 **추가** 비용. `tick_cost = cost_base + get_additive(depth_m)`.
## FUEL_SYSTEM_DESIGN.md §4-1 — 계단식 하한 테이블.

const DEPTH_THRESHOLDS_M: Array[float] = [0.0, 50.0, 100.0, 200.0]
const COST_ADDITIVE: Array[float] = [0.0, 0.5, 1.0, 2.0]


static func get_additive(depth_m: float) -> float:
	if depth_m < 0.0:
		return 0.0
	var cost: float = 0.0
	for i in DEPTH_THRESHOLDS_M.size():
		if depth_m >= DEPTH_THRESHOLDS_M[i]:
			cost = COST_ADDITIVE[i]
	return cost

class_name SkillDef
extends Resource

## 스킬 하나의 정의 데이터.
## CSV에서 파싱되어 생성되며, 런타임에는 읽기 전용으로 사용한다.

var id: StringName
var display_name: String
var description: String
var max_level: int

## 레벨당 비용. CSV의 base + growth 공식으로 계산되어 채워진다.
## 인덱스 0 = 1레벨 비용, 인덱스 1 = 2레벨 비용, ...
## 레벨 N 비용 = base + growth × (N - 1)
var cost_per_level: Array[SkillCost] = []

## 이 스킬이 적용하는 스탯 효과 목록.
var effects: Array[SkillEffect] = []

## 공개 조건: 이 목록의 모든 스킬이 1레벨 이상이어야 함 (AND 조건).
var prerequisites: Array[StringName] = []

## 이 스킬을 1레벨 이상 배우면 공개되는 후속 스킬 id 목록.
var unlocks: Array[StringName] = []

## UI 트리에서 이 노드를 배치할 좌표.
var position: Vector2 = Vector2.ZERO

extends Node

## 전역 게임 상태 (자원, 골드, 인벤 참조 등).

const c_RootSkillId: StringName = &"drill_basic"

## { 스킬id: 현재레벨 }. 미습득 스킬은 키 없음.
var learned_skills: Dictionary = {}

## 현재 트리에 표시 중인 스킬 id 목록.
var visible_skills: Array[StringName] = []

## 달러. 달러 획득 시스템 구현 전까지 0으로 유지.
var dollars: int = 0

## 광석 인벤토리. { ore_id: StringName -> amount: int }
var ore_inventory: Dictionary = {}


func _ready() -> void:
	# Autoload는 메인 씬·자식 노드보다 먼저 _ready됨. World가 청크를 채우기 전에 실행해야 함.
	WorldGenerator.randomize_run_seed()
	visible_skills = [c_RootSkillId]
	print("GameState: visible_skills = ", visible_skills)


func can_afford(_cost: SkillCost) -> bool:
	if dollars < _cost.dollar_cost:
		return false
	for oreId in _cost.ore_costs:
		var required: int = _cost.ore_costs[oreId]
		var owned: int = ore_inventory.get(oreId, 0)
		if owned < required:
			return false
	return true


func deduct_cost(_cost: SkillCost) -> void:
	dollars -= _cost.dollar_cost
	for oreId in _cost.ore_costs:
		ore_inventory[oreId] = ore_inventory.get(oreId, 0) - _cost.ore_costs[oreId]

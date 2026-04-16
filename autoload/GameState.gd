extends Node

## 전역 게임 상태 (자원, 골드, 인벤 참조 등).

const c_RootSkillId: StringName = &"drill_basic"

## { 스킬id: 현재레벨 }. 미습득 스킬은 키 없음.
var learned_skills: Dictionary = {}

## 현재 트리에 표시 중인 스킬 id 목록.
var visible_skills: Array[StringName] = []

## 달러 잔액이 변경될 때 emit. SkillTreeView 등이 구독해 색상을 갱신한다.
signal dollars_changed

## 달러. 달러 획득 시스템 구현 전까지 0으로 유지.
var dollars: int = 0

## 채굴 중 사용하는 임시 배낭. 출발 시 비워지고, 귀환 시 hub_inventory로 이전된다.
var run_inventory: RunInventory = RunInventory.new()

## run_inventory UI 표시용 카운트. { item_id -> 표시 개수 }
## 실제 슬롯(run_inventory)은 픽업 판정 즉시 반영, 이 값은 아이콘 소멸 시 반영.
var run_display: Dictionary = {}

## 거점 영구 보관함. 런을 넘어 유지되며 스킬 구매 비용 차감에 사용된다.
var hub_inventory: HubInventory = HubInventory.new()


func _ready() -> void:
	# Autoload는 메인 씬·자식 노드보다 먼저 _ready됨. World가 청크를 채우기 전에 실행해야 함.
	WorldGenerator.randomize_run_seed()
	visible_skills = [c_RootSkillId]
	print("GameState: visible_skills = ", visible_skills)


## 출발 전 호출. run_inventory와 표시용 카운트를 모두 비운다.
func start_run() -> void:
	run_inventory.resize_slots(int(StatSystem.get_final(&"inventory_slot_count")))
	run_inventory.max_stack = int(StatSystem.get_final(&"inventory_max_stack"))
	run_inventory.clear()
	run_display.clear()


## DropItem 아이콘이 드릴에 도달했을 때 호출. 표시용 카운트만 증가.
func confirm_pickup(_item_id: StringName, _count: int) -> void:
	run_display[_item_id] = run_display.get(_item_id, 0) + _count


## 귀환 시 호출. run_inventory 전량을 hub_inventory로 이전한 뒤 비운다.
## hub_inventory는 한계가 없으므로 항상 전량 이전 성공.
func transfer_run_to_hub() -> void:
	for slot in run_inventory.slots:
		if slot["item_id"] == &"" or slot["count"] <= 0:
			continue
		hub_inventory.add_item(slot["item_id"], slot["count"])
	run_inventory.clear()


## 스킬 구매 가능 여부. hub_inventory 기준으로 확인한다.
func can_afford(_cost: SkillCost) -> bool:
	if dollars < _cost.dollar_cost:
		return false
	for oreId in _cost.ore_costs:
		var required: int = _cost.ore_costs[oreId]
		if hub_inventory.get_count(oreId) < required:
			return false
	return true


## 스킬 구매 비용 차감. hub_inventory 기준으로 차감한다.
func deduct_cost(_cost: SkillCost) -> void:
	dollars -= _cost.dollar_cost
	if _cost.dollar_cost != 0:
		dollars_changed.emit()
	for oreId in _cost.ore_costs:
		hub_inventory.remove_item(oreId, _cost.ore_costs[oreId])

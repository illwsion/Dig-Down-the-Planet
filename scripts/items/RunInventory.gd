class_name RunInventory
extends Resource

## 채굴 중 사용하는 임시 배낭. 슬롯 수·슬롯당 최대 스택이 제한된다.
## 출발 시 clear(), 귀환 시 GameState.transfer_run_to_hub()로 비워진다.
## 슬롯 수·max_stack은 스킬 업그레이드로 GameState에서 갱신한다.

const c_DefaultSlotCount: int = 4
const c_DefaultMaxStack: int = 3

## 현재 최대 슬롯 수. 스킬로 증가 가능.
var slot_count: int = c_DefaultSlotCount

## 슬롯당 최대 아이템 수. 스킬로 증가 가능.
var max_stack: int = c_DefaultMaxStack

## 슬롯 배열. 각 슬롯은 { "item_id": StringName, "count": int }.
## 길이는 항상 slot_count와 동일하게 유지된다.
var slots: Array = []


func _init() -> void:
	_resize_slots(slot_count)


## 모든 슬롯을 비운다. 출발 전 호출.
func clear() -> void:
	for slot in slots:
		slot["item_id"] = &""
		slot["count"] = 0


## 아이템 추가 시도. 전량 수납 성공이면 true, 공간 부족이면 false.
## 우선순위: 같은 id가 있고 max_stack 미만인 슬롯 → 빈 슬롯.
func add_item(_item_id: StringName, _count: int) -> bool:
	var remaining: int = _count

	# 1단계: 기존 슬롯에 합산
	for slot in slots:
		if remaining <= 0:
			break
		if slot["item_id"] != _item_id:
			continue
		var space: int = max_stack - slot["count"]
		var fill: int = mini(space, remaining)
		slot["count"] += fill
		remaining -= fill

	# 2단계: 빈 슬롯 사용
	for slot in slots:
		if remaining <= 0:
			break
		if slot["item_id"] != &"":
			continue
		var fill: int = mini(max_stack, remaining)
		slot["item_id"] = _item_id
		slot["count"] = fill
		remaining -= fill

	return remaining <= 0


## 아이템을 1개라도 더 넣을 수 있으면 true.
func can_add(_item_id: StringName) -> bool:
	for slot in slots:
		if slot["item_id"] == _item_id and slot["count"] < max_stack:
			return true
		if slot["item_id"] == &"":
			return true
	return false


## 특정 아이템의 총 보유 수량.
func get_count(_item_id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if slot["item_id"] == _item_id:
			total += slot["count"]
	return total


## 슬롯 수를 늘린다. 스킬 업그레이드 시 호출. 기존 슬롯 내용은 유지.
func _resize_slots(_new_count: int) -> void:
	slot_count = _new_count
	while slots.size() < slot_count:
		slots.append({"item_id": &"", "count": 0})

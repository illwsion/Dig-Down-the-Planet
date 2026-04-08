class_name HubInventory
extends Resource

## 거점 영구 보관함. 슬롯·스택 제한 없이 종류와 개수만 저장한다.

## { item_id: StringName -> count: int }
var items: Dictionary = {}

## 한 번이라도 추가된 적 있는 아이템 id 목록. 개수가 0이 돼도 유지된다.
var discovered: Array[StringName] = []


## 아이템 추가. 한계 없으므로 항상 성공.
func add_item(_item_id: StringName, _count: int) -> void:
	if _item_id == &"" or _count <= 0:
		return
	items[_item_id] = items.get(_item_id, 0) + _count
	if not discovered.has(_item_id):
		discovered.append(_item_id)


## 아이템 제거. 보유량이 부족하면 false 반환.
func remove_item(_item_id: StringName, _count: int) -> bool:
	var owned: int = items.get(_item_id, 0)
	if owned < _count:
		return false
	var remaining: int = owned - _count
	if remaining <= 0:
		items.erase(_item_id)
	else:
		items[_item_id] = remaining
	return true


## 특정 아이템의 보유 수량 반환. 없으면 0.
func get_count(_item_id: StringName) -> int:
	return items.get(_item_id, 0)

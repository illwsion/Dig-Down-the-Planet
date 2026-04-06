class_name BlockDef
extends Resource

## 블록 종류 한 행(데이터 테이블용).

@export var id: StringName = &"dirt"
@export var max_hp: int = 3
@export var display_name: String = "흙"

## 파괴 시 드롭할 아이템 id. 빈 문자열이면 드롭 없음.
@export var drop_item_id: StringName = &""
## 드롭 개수.
@export var drop_count: int = 1

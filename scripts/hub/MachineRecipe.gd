class_name MachineRecipe
extends Resource

## 기계 레시피 1줄 정의. 어떤 아이템을 넣으면 어떤 아이템이 나오는지만 정의한다.
## 투입/산출 개수는 MachineDef.input_count / output_count 로 결정된다.

## 투입 아이템 id.
@export var input_id: StringName = &""

## 산출 아이템 id.
@export var output_id: StringName = &""

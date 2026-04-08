class_name MachineDef
extends Resource

## 기계 한 종류의 정의. 인스펙터에서 데이터를 채운 뒤 .tres로 저장해 MachineNode에 연결한다.

## 고유 식별자.
@export var id: StringName = &""

## 화면에 표시할 기계 이름.
@export var display_name: String = ""

## 가공 시간 (초). RUNNING 상태에서 이 시간이 지나면 DONE으로 전환된다.
@export var process_time: float = 5.0

## 클릭 횟수 목표. 이 수만큼 투입해야 FULL 상태가 된다.
## 처리량 업그레이드로 증가한다.
@export var input_count: int = 1

## 가공 완료 시 산출되는 아이템 개수.
## 효율 업그레이드로 증가한다.
@export var output_count: int = 1

## 레시피 목록. 투입 → 산출 변환 규칙을 정의한다.
@export var recipes: Array[MachineRecipe] = []

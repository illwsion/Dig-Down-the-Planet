class_name ItemDef
extends Resource

## 아이템 한 종류의 정의. ItemDatabase가 CSV에서 파싱해 런타임에 생성한다.

## 고유 식별자. DropItem·Inventory 등 모든 곳에서 이 id로 아이템을 구분한다.
var id: StringName = &""

var display_name: String = ""

## 인벤토리 슬롯 및 DropItem 스프라이트에 사용할 아이콘.
## 우선 공용 플레이스홀더를 사용. 추후 아이템별 스프라이트로 교체 예정.
var icon: Texture2D = preload("res://assets/sprites/image_32.png")

## 추후 상점에서 달러로 환산할 기준 가격.
var sell_price: int = 1

## 인벤토리 패널 탭 분류. "raw" = 원자재, "processed" = 가공품.
var category: StringName = &"raw"

# 인벤토리 & 드롭 아이템 시스템 기획

## 프로젝트 현황 요약

| 시스템 | 상태 |
|--------|------|
| 무한 청크 월드 스트리밍 | ✅ 완성 |
| 타일 HP·채굴·파괴 (`Chunk._break_cell`) | ✅ 완성 |
| 드릴 이동/물리 (`Drill.gd`) | ✅ 완성 |
| 스킬 트리 UI | ✅ 완성 |
| `GameState` autoload | ✅ 완성 |
| `ore_inventory: Dictionary` 껍데기 | ✅ 선언만 |
| 인벤토리 시스템 | ❌ 없음 |
| 드롭 아이템 시스템 | ❌ 없음 |

---

## 인벤토리 이중 구조 설계

채굴 런과 거점을 구분하는 두 개의 인벤토리를 사용한다.

### 개념도

```
[ 거점(Hub) ]                        [ 채굴(Main) ]
     │                                     │
  hub_inventory                       run_inventory
  (영구 보관함)                        (임시 배낭)
  - 런을 넘어 유지                     - 출발 시 비워짐
  - 스킬 구매 비용 차감                - 드롭 아이템 수집
  - 거점 UI에서 확인                   - 용량 꽉 차면 픽업 불가
     │                                     │
     └────────────── 귀환 시 이전 ──────────┘
                   transfer_run_to_hub()
```

### 런 흐름

```
[Hub] 출발 버튼 클릭
    └─ GameState.run_inventory.clear()
    └─ 씬 전환 → Main.tscn

[Main] 채굴 중
    └─ 타일 파괴 → DropItem 스폰
    └─ 드릴 접근 → run_inventory.add_item()
    └─ run_inventory 꽉 참 → 픽업 불가

[Main] 귀환 버튼 클릭
    └─ GameState.transfer_run_to_hub()
    └─ 씬 전환 → Hub.tscn

[Hub] 귀환 후
    └─ hub_inventory에 채굴 결과 반영됨
    └─ 스킬 구매, 판매 등에 hub_inventory 사용
```

---

## 아이템 & 드롭 데이터 구조

### 아이템 추가 방법

`resources/items/item_database.csv` 에 행 하나만 추가하면 된다.

```
id,display_name,sell_price
dirt,흙,1
stone,돌,2        ← 이렇게 한 줄만 추가
```

### `ItemDef.gd` — 아이템 정의 (런타임 생성)

`@export` 없음. `ItemDatabase`가 CSV를 파싱해 런타임에 인스턴스를 생성한다.

```gdscript
class_name ItemDef
extends Resource

var id: StringName = &""
var display_name: String = ""
var icon: Texture2D = preload("res://assets/sprites/image_32.png")  # 공용 플레이스홀더
var sell_price: int = 1
```

### `ItemDatabase.gd` — Autoload (CSV 파싱)

```gdscript
# _ready()에서 CSV 로드 → _defs Dictionary 캐시
# ItemDatabase.get_def(&"dirt")  →  ItemDef 반환
```

### `BlockDef.gd` — 블록 정의 (드롭 정보 포함)

```gdscript
@export var id: StringName = &"dirt"
@export var max_hp: int = 3
@export var display_name: String = "흙"
@export var drop_item_id: StringName = &""   # 빈 문자열이면 드롭 없음
@export var drop_count: int = 1
```

**흙 블록 드롭 설정 (`block_table.tres`)**
- `BlockDef(id="dirt", drop_item_id="dirt", drop_count=1)` — .tres 파일에 직접 저장됨

---

## 인벤토리 데이터 구조

두 인벤토리는 구조가 완전히 다르므로 별도 클래스로 분리한다.

---

### `HubInventory.gd` — 거점 보관함 (한계 없음)

슬롯 개념 없이 `Dictionary` 하나로 관리. 종류와 개수만 저장.

```gdscript
class_name HubInventory
extends Resource

# { item_id: StringName -> count: int }
var items: Dictionary = {}

# 아이템 추가. 한계 없으므로 항상 성공.
func add_item(_item_id: StringName, _count: int) -> void:
    items[_item_id] = items.get(_item_id, 0) + _count

# 아이템 제거. 부족하면 false.
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

# 보유 수량 반환.
func get_count(_item_id: StringName) -> int:
    return items.get(_item_id, 0)
```

---

### `RunInventory.gd` — 채굴 임시 배낭 (슬롯 제한)

슬롯 수와 슬롯당 최대 스택이 모두 제한됨. 스킬로 업그레이드 가능.

```gdscript
class_name RunInventory
extends Resource

# 초기값. 스킬 업그레이드로 GameState에서 갱신.
const c_DefaultSlotCount: int = 4
const c_DefaultMaxStack: int  = 3

var slot_count: int = c_DefaultSlotCount   # 현재 최대 슬롯 수
var max_stack: int  = c_DefaultMaxStack    # 슬롯당 최대 아이템 수

# 슬롯 배열. 길이는 항상 slot_count와 동일하게 유지.
# 각 슬롯: { "item_id": StringName, "count": int }
var slots: Array = []

func _init() -> void:
    _resize_slots(slot_count)

# 슬롯을 전부 비움. 출발 전 호출.
func clear() -> void:
    for slot in slots:
        slot["item_id"] = &""
        slot["count"]   = 0

# 아이템 1회 추가 시도. 성공 true, 공간 없으면 false.
# 우선순위: 같은 id가 있고 max_stack 미만인 슬롯 → 빈 슬롯.
func add_item(_item_id: StringName, _count: int) -> bool:
    var remaining: int = _count

    # 1단계: 기존 슬롯에 합산
    for slot in slots:
        if remaining <= 0:
            break
        if slot["item_id"] != _item_id:
            continue
        var space: int = max_stack - slot["count"]
        var fill: int  = mini(space, remaining)
        slot["count"] += fill
        remaining     -= fill

    # 2단계: 빈 슬롯 사용
    for slot in slots:
        if remaining <= 0:
            break
        if slot["item_id"] != &"":
            continue
        var fill: int  = mini(max_stack, remaining)
        slot["item_id"] = _item_id
        slot["count"]   = fill
        remaining       -= fill

    return remaining <= 0   # 전부 넣으면 true, 일부라도 남으면 false

# 1개라도 더 넣을 수 있는지 확인.
func can_add(_item_id: StringName) -> bool:
    for slot in slots:
        if slot["item_id"] == _item_id and slot["count"] < max_stack:
            return true
        if slot["item_id"] == &"":
            return true
    return false

# 특정 아이템 총 보유 수량.
func get_count(_item_id: StringName) -> int:
    var total: int = 0
    for slot in slots:
        if slot["item_id"] == _item_id:
            total += slot["count"]
    return total

# 슬롯 수 변경 (스킬 업그레이드 시 호출). 기존 내용 유지.
func _resize_slots(_new_count: int) -> void:
    slot_count = _new_count
    while slots.size() < slot_count:
        slots.append({"item_id": &"", "count": 0})
```

**초기 스펙 요약**

| 항목 | 초기값 | 비고 |
|------|--------|------|
| 슬롯 수 | 4 | 스킬로 증가 |
| 슬롯당 최대 스택 | 3 | 스킬로 증가 |
| 최대 수용량 | 4 × 3 = 12개 | 초기 상태 |

---

### `GameState.gd` 변경

```gdscript
# 기존 (제거)
var ore_inventory: Dictionary = {}

# 추가
var run_inventory: RunInventory = RunInventory.new()
var hub_inventory: HubInventory = HubInventory.new()

# 출발 전 run_inventory 초기화. Hub._on_start_button_pressed()에서 호출.
func start_run() -> void:
    run_inventory.clear()

# 귀환 시 run_inventory → hub_inventory 전부 이전.
# Main._on_return_button_pressed()에서 호출.
# hub_inventory는 한계 없으므로 항상 전량 이전 성공.
func transfer_run_to_hub() -> void:
    for slot in run_inventory.slots:
        if slot["item_id"] == &"" or slot["count"] <= 0:
            continue
        hub_inventory.add_item(slot["item_id"], slot["count"])
    run_inventory.clear()
```

> `can_afford` / `deduct_cost` 는 **`hub_inventory`** 기준으로 변경.
> 스킬 구매는 거점에서만 이루어지므로 `run_inventory`는 관여하지 않는다.

---

## 드롭 아이템 씬 동작 설계

### 씬 구조: `DropItem.tscn`

```
DropItem (Area2D)
├── Sprite2D              ← 아이템 아이콘 (위아래 진동)
└── CollisionShape2D      ← 작은 원형, 픽업 감지용 (레이어 2)
```

> 물리 바디 없음. 위치는 코드로만 제어.

### 스폰 흐름

```
Chunk._break_cell(local_cell)
    │
    ├─ block_id = block_id_for_cell(local_cell)
    ├─ def = BlockTable.get_def(block_id)       ← BlockTable에 get_def() 추가 필요
    ├─ if def.drop_table == null → 종료
    │
    ├─ drops = def.drop_table.roll()            ← { item_id → count }
    │
    └─ for item_id, count in drops:
           world_pos = to_global(Vector2(local_cell) * TILE_SIZE_PX + Vector2(16, 16))
           DropItem 인스턴스 스폰 (item_id, count, world_pos)
           get_tree().root.add_child(drop)      ← 청크보다 오래 살아야 함
```

### DropItem 동작 (`DropItem.gd`)

#### 스폰 직후 초기화

```gdscript
func setup(_item_id: StringName, _count: int, _spawn_pos: Vector2) -> void:
    item_id = _item_id
    count   = _count
    global_position = _spawn_pos
```

#### 위아래 둥둥 효과 (Sprite2D만)

```gdscript
# DropItem 자체의 global_position은 고정.
# Sprite2D의 로컬 y만 sin으로 진동.
func _process(delta: float) -> void:
    m_bob_phase += delta * TAU   # 1회전/s
    m_sprite.position.y = sin(m_bob_phase) * 3.5   # ±3.5 px
```

#### 자동 픽업

```gdscript
func _process(delta: float) -> void:
    ...
    var drill = get_tree().get_first_node_in_group("drill")
    if drill == null:
        return

    var dist = global_position.distance_to(drill.get_tip_global_position())
    if dist > pickup_radius:    # pickup_radius ≈ 80 px (추후 스킬로 확장)
        return

    var success = GameState.run_inventory.add_item(item_id, count, ItemDatabase)
    if success:
        queue_free()
    # 꽉 차면 대기 (사라지지 않음)
```

#### 픽업 흐름 요약

```
[드릴 tip] ── pickup_radius 이내 ──▶ [DropItem]
                                         │
                              run_inventory.add_item()
                                    ├── true  → queue_free()
                                    └── false → 대기 (run_inventory 꽉 참)
```

---

## 전체 데이터 흐름 다이어그램

```
[Hub] 출발 버튼
    └─ GameState.start_run()  →  run_inventory 초기화
    └─ 씬 전환 Main.tscn

[Main] 마우스 클릭 홀드
    └─ Drill._process_mining_tick()
    └─ World.apply_mine_damage_at_world()
    └─ Chunk.apply_damage_at_local_if_mineable()
    └─ Chunk._break_cell()
          ├─ 타일·충돌 제거 (기존)
          └─ DropTable.roll()  →  DropItem 스폰

[DropItem] 매 프레임
    ├─ Sprite2D sin 진동 (둥둥)
    └─ 드릴 tip 거리 체크
          └─ 범위 이내  →  run_inventory.add_item()
                              ├─ true  → queue_free()
                              └─ false → 대기

[Main] 귀환 버튼
    └─ GameState.transfer_run_to_hub()
          └─ run_inventory 슬롯 순회 → hub_inventory.add_item()
          └─ run_inventory.clear()
    └─ 씬 전환 Hub.tscn

[Hub] 스킬 구매
    └─ GameState.can_afford()   ← hub_inventory 기준
    └─ GameState.deduct_cost()  ← hub_inventory 기준
```

---

## 파일 목록

### 신규 생성

| 파일 | 종류 | 역할 |
|------|------|------|
| `scripts/items/ItemDef.gd` | class | 아이템 정의 (런타임 생성) |
| `scripts/items/RunInventory.gd` | Resource | 슬롯 기반 임시 배낭 |
| `scripts/items/HubInventory.gd` | Resource | Dictionary 기반 거점 보관함 |
| `scripts/items/ItemDatabase.gd` | Autoload | CSV 파싱·캐시, id → ItemDef 조회 |
| `scripts/world/DropItem.gd` | Node 스크립트 | 월드 드롭 아이템 동작 |
| `scenes/world/DropItem.tscn` | 씬 | DropItem 씬 |
| `resources/items/item_database.csv` | CSV | 아이템 데이터 (행 추가로 확장) |

### 기존 파일 수정

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/world/BlockDef.gd` | `drop_table` 제거 → `drop_item_id`, `drop_count` 추가 |
| `scripts/world/BlockTable.gd` | `get_def(id) -> BlockDef` 메서드 추가 |
| `scripts/world/Chunk.gd` | `_break_cell()` 에 드롭 스폰 로직 삽입 |
| `autoload/GameState.gd` | `ore_inventory` 제거, `run_inventory` / `hub_inventory` 추가, `start_run()` / `transfer_run_to_hub()` 추가, `can_afford` / `deduct_cost` 를 `hub_inventory` 기준으로 변경 |
| `scenes/hub/Hub.gd` | `_on_start_button_pressed()` 에서 `GameState.start_run()` 호출 추가 |
| `scenes/main/Main.gd` | `_on_return_button_pressed()` 에서 `GameState.transfer_run_to_hub()` 호출 추가 |
| `scripts/player/Drill.gd` | `add_to_group("drill")` 추가 |
| `resources/world/block_table.tres` | `drop_table` 참조 제거, `drop_item_id`/`drop_count` 직접 저장 |

---

## 구현 순서

> 각 단계는 독립적으로 완료 가능한 한 가지 작업이다.
> 앞 단계가 끝난 뒤 다음 단계로 넘어간다.

---

### Phase 1 — 아이템 데이터 정의 (스크립트만, 씬 없음)

#### STEP 1. `ItemDef.gd` 작성
- 파일: `scripts/items/ItemDef.gd` 신규 생성
- 내용: `id`, `display_name`, `icon`, `max_stack`, `sell_price` 필드
- 완료 기준: 에디터에서 class_name `ItemDef` 인식됨

#### ~~STEP 2. `DropEntry.gd` 작성~~ → 삭제 (CSV 방식으로 대체)

#### ~~STEP 3. `DropTable.gd` 작성~~ → 삭제 (BlockDef에 직접 포함)

---

### Phase 2 — 인벤토리 로직 (스크립트만)

#### STEP 4. `HubInventory.gd` 작성
- 파일: `scripts/items/HubInventory.gd` 신규 생성
- 내용: `items: Dictionary`, `add_item()`, `remove_item()`, `get_count()`
- 완료 기준: 에디터에서 class_name `HubInventory` 인식됨

#### STEP 5. `RunInventory.gd` 작성
- 파일: `scripts/items/RunInventory.gd` 신규 생성
- 내용: `slots: Array`, `slot_count=4`, `max_stack=3`, `_init()`, `clear()`, `add_item()`, `can_add()`, `get_count()`, `_resize_slots()`
- 완료 기준: 에디터에서 class_name `RunInventory` 인식됨

---

### Phase 3 — ItemDatabase Autoload 등록

#### STEP 6. `ItemDatabase.gd` 작성
- 파일: `scripts/items/ItemDatabase.gd` 신규 생성
- 내용:
  - `@export var item_defs: Array[ItemDef]`
  - `func get_def(_id: StringName) -> ItemDef` — 배열 순회로 id 일치 항목 반환, 없으면 null
- 완료 기준: 에디터에서 class_name `ItemDatabase` 인식됨

#### STEP 7. `project.godot`에 ItemDatabase Autoload 등록
- Godot 에디터 > Project > Project Settings > Autoload 탭
- `scripts/items/ItemDatabase.gd` 를 `ItemDatabase` 이름으로 추가
- 완료 기준: 다른 스크립트에서 `ItemDatabase.get_def(...)` 전역 호출 가능

---

### Phase 4 — 블록 데이터에 드롭 테이블 연결

#### STEP 8. `BlockDef.gd`에 `drop_item_id` / `drop_count` 필드 추가
- 파일: `scripts/world/BlockDef.gd` 수정
- 내용: `drop_table: DropTable` 제거 → `drop_item_id: StringName`, `drop_count: int` 추가
- 완료 기준: 에디터에서 `block_table.tres` 의 dirt 블록 인스펙터에 두 필드 표시됨

#### STEP 9. `BlockTable.gd`에 `get_def()` 메서드 추가
- 파일: `scripts/world/BlockTable.gd` 수정
- 내용: `func get_def(_id: StringName) -> BlockDef` — `get_max_hp()`와 같은 방식으로 배열 순회
- 완료 기준: `block_table.get_def(&"dirt")` 가 null이 아닌 BlockDef 반환

#### STEP 10. `item_database.csv` 생성
- 파일: `resources/items/item_database.csv` 신규 생성
- 내용: 헤더 + 흙 아이템 행 1줄
- 완료 기준: 파일 존재, 새 아이템은 행 추가만으로 등록 가능

#### ~~STEP 11. `drop_table_dirt.tres` 생성~~ → 삭제 (BlockDef에 직접 포함)

#### STEP 12. `block_table.tres` 정리
- `drop_table` 참조 제거, dirt 블록에 `drop_item_id = "dirt"`, `drop_count = 1` 직접 저장
- 완료 기준: 에디터에서 오류 없이 로드됨

#### ~~STEP 13. `ItemDatabase` Autoload에 `.tres` 등록~~ → 불필요 (CSV 자동 로드)

---

### Phase 5 — GameState 교체

#### STEP 14. `GameState.gd`에서 `ore_inventory` 제거하고 두 인벤토리 추가
- 파일: `autoload/GameState.gd` 수정
- `var ore_inventory: Dictionary` 제거
- `var run_inventory: RunInventory = RunInventory.new()` 추가
- `var hub_inventory: HubInventory = HubInventory.new()` 추가
- 완료 기준: 에디터 오류 없음 (ore_inventory 참조 코드가 없으므로 바로 통과)

#### STEP 15. `GameState.gd`에 `start_run()` / `transfer_run_to_hub()` 추가
- `func start_run()` — `run_inventory.clear()` 호출
- `func transfer_run_to_hub()` — run_inventory 슬롯 순회 → hub_inventory.add_item() → run_inventory.clear()
- 완료 기준: 함수 두 개 추가, 에디터 오류 없음

#### STEP 16. `GameState.gd`의 `can_afford()` / `deduct_cost()` 를 hub_inventory 기준으로 수정
- 기존: `ore_inventory.get(oreId, 0)` 으로 보유량 확인 및 차감
- 변경: `hub_inventory.get_count(oreId)` 확인, `hub_inventory.remove_item(oreId, amount)` 차감
- 완료 기준: 스킬 트리에서 구매 시도 시 에러 없음

---

### Phase 6 — 드롭 아이템 씬 제작

#### STEP 17. `DropItem.tscn` 씬 생성
- 에디터에서 새 씬: 루트를 `Area2D` 로 생성, 이름 `DropItem`
- 자식 추가: `Sprite2D` (이름 `Sprite2D`), `CollisionShape2D` (이름 `CollisionShape2D`)
- `CollisionShape2D` 에 `CircleShape2D` 할당, 반경 8px
- `scenes/world/DropItem.tscn` 으로 저장
- 완료 기준: 씬 파일 저장됨

#### STEP 18. `DropItem.gd` 작성 — 기본 구조 + `setup()`
- 파일: `scripts/world/DropItem.gd` 신규 생성
- 내용: `item_id`, `count`, `pickup_radius = 80.0` 변수, `setup()` 함수
- `DropItem.tscn` 에 스크립트 연결
- 완료 기준: 씬에 스크립트 연결됨, 에러 없음

#### STEP 19. `DropItem.gd`에 둥둥 효과 추가
- `_process(delta)` 에 `m_bob_phase` 누적 + `m_sprite.position.y = sin(m_bob_phase) * 3.5` 추가
- 완료 기준: 씬을 직접 실행하면 Sprite2D가 위아래로 진동함

#### STEP 20. `DropItem.gd`에 자동 픽업 로직 추가
- `_process(delta)` 에 "drill" 그룹에서 드릴 노드 찾기
- tip과의 거리 계산 → `pickup_radius` 이내면 `GameState.run_inventory.add_item()` 호출
- 성공 시 `queue_free()`, 실패(꽉 참) 시 대기
- 완료 기준: 코드 작성 완료 (STEP 21 이후에 실제 동작 확인)

---

### Phase 7 — 채굴 → 드롭 연결

#### STEP 21. `Drill.gd`에 `"drill"` 그룹 추가
- 파일: `scripts/player/Drill.gd` 수정
- `_ready()` 안에 `add_to_group("drill")` 한 줄 추가
- 완료 기준: 런타임에서 `get_tree().get_first_node_in_group("drill")` 이 Drill 노드 반환

#### STEP 22. `Chunk._break_cell()`에 드롭 스폰 훅 삽입
- 파일: `scripts/world/Chunk.gd` 수정
- `_break_cell()` 내 기존 로직 뒤에 추가:
  1. `block_id_for_cell(local_cell)` 로 블록 id 조회
  2. `block_table.get_def(block_id)` 로 BlockDef 조회
  3. `def.drop_table` 이 null이면 종료
  4. `def.drop_table.roll()` 로 드롭 목록 획득
  5. 각 item_id / count 에 대해 DropItem 프리팹 인스턴스 생성 후 `get_tree().root.add_child()`
  6. `drop.setup(item_id, count, world_pos)` 호출
- 완료 기준: 흙 블록 파괴 시 DropItem이 스폰되어 둥둥 떠다님

---

### Phase 8 — 런 흐름 연결

#### STEP 23. `Hub.gd` — 출발 버튼에 `GameState.start_run()` 추가
- 파일: `scenes/hub/Hub.gd` 수정
- `_on_start_button_pressed()` 내 씬 전환 전에 `GameState.start_run()` 호출
- 완료 기준: 출발 시 run_inventory가 비워진 상태로 Main으로 진입

#### STEP 24. `Main.gd` — 귀환 버튼에 `GameState.transfer_run_to_hub()` 추가
- 파일: `scenes/main/Main.gd` 수정
- `_on_return_button_pressed()` 내 씬 전환 전에 `GameState.transfer_run_to_hub()` 호출
- 완료 기준: 귀환 후 `GameState.hub_inventory.items` 에 채굴한 흙이 쌓임

---

### 단계 요약표

| 단계 | 작업 | 유형 |
|------|------|------|
| STEP 1 | `ItemDef.gd` 작성 | ✅ 완료 |
| ~~STEP 2~~ | ~~`DropEntry.gd`~~ | ❌ 삭제 |
| ~~STEP 3~~ | ~~`DropTable.gd`~~ | ❌ 삭제 |
| STEP 4 | `HubInventory.gd` 작성 | ✅ 완료 |
| STEP 5 | `RunInventory.gd` 작성 | ✅ 완료 |
| STEP 6 | `ItemDatabase.gd` 작성 | ✅ 완료 |
| STEP 7 | `ItemDatabase` Autoload 등록 | ✅ 완료 |
| STEP 8 | `BlockDef.gd` `drop_item_id`/`drop_count` 추가 | ✅ 완료 |
| STEP 9 | `BlockTable.gd` `get_def()` 추가 | ✅ 완료 |
| STEP 10 | `item_database.csv` 생성 | ✅ 완료 |
| ~~STEP 11~~ | ~~`drop_table_dirt.tres`~~ | ❌ 삭제 |
| STEP 12 | `block_table.tres` 정리 | ✅ 완료 |
| ~~STEP 13~~ | ~~ItemDatabase .tres 등록~~ | ❌ 불필요 |
| STEP 14 | `GameState.gd` 인벤토리 교체 | 🔲 미완료 |
| STEP 15 | `GameState.gd` `start_run()` / `transfer_run_to_hub()` 추가 | 🔲 미완료 |
| STEP 16 | `GameState.gd` `can_afford()` / `deduct_cost()` 수정 | 🔲 미완료 |
| STEP 17 | `DropItem.tscn` 씬 생성 | 🔲 미완료 |
| STEP 18 | `DropItem.gd` 기본 구조 + `setup()` | 🔲 미완료 |
| STEP 19 | `DropItem.gd` 둥둥 효과 | 🔲 미완료 |
| STEP 20 | `DropItem.gd` 자동 픽업 로직 | 🔲 미완료 |
| STEP 21 | `Drill.gd` 그룹 추가 | 🔲 미완료 |
| STEP 22 | `Chunk._break_cell()` 드롭 스폰 훅 | 🔲 미완료 |
| STEP 23 | `Hub.gd` 출발 시 `start_run()` | 🔲 미완료 |
| STEP 24 | `Main.gd` 귀환 시 `transfer_run_to_hub()` | 🔲 미완료 |

---

## 미결 사항 (추후 결정)

| 항목 | 현재 기본값 | 추후 확장 |
|------|-------------|-----------|
| run_inventory 슬롯 수 | 4 | 스킬로 증가 |
| run_inventory 슬롯당 최대 스택 | 3 | 스킬로 증가 |
| hub_inventory 한계 | 없음 (Dictionary) | 변경 없음 |
| 픽업 범위 (`pickup_radius`) | 80 px | 스킬 효과로 증가 |
| 드롭 개수 | 1개 고정 | 드롭률 스킬 효과로 배율 적용 |
| 드롭 아이템 수명 | 무제한 | 일정 시간 후 사라지도록 추가 가능 |
| run_inventory UI | 미정 | 채굴 중 HUD에 배낭 아이콘/슬롯 표시 |
| hub_inventory UI | 미정 | Hub 씬에서 보관함 패널 표시 |

# 허브(Hub) 자원 가공 & 달러 변환 시스템 설계

Godot 4 / GDScript 기준. 기존 `hub_inventory` → 가공 기계 → 달러($) 획득 흐름을 정의한다.

---

## 1. 시스템 개요

```
[Main 씬] 채굴
    └─ 자원 (흙, 돌, 구리, 철 …) → run_inventory
           │
           └─ 귀환 (transfer_run_to_hub)
                  │
           [Hub 씬] hub_inventory (창고)
                  │
         ┌────────┴────────┐
    압착기(Compressor)   용광로(Furnace)
    흙·돌 → 벽돌         구리·철·은·금 → 주괴
         │                    │
         └────────┬────────────┘
              인벤토리 수집 (마우스 올리기)
                  │
             Hub 인벤토리 패널 (벽돌, 주괴 보관)
                  │
              자원 판매 → GameState.dollars ↑
```

### 핵심 결정 사항

| 항목 | 결정 |
|------|------|
| 기계 잠금 해제 순서 | 압착기 → (달러 충분 시) 용광로 해금 |
| 투입 트리거 | 초기: 기계 클릭 시 창고에서 자원 자동 투입 |
| 작동 트리거 | 초기: 레버 수동 클릭 |
| 완성품 수거 | 초기: 마우스 올리기(hover) |
| 자동화 경로 | 업그레이드로 단계별 자동화 |

---

## 2. 아이템 종류 확장

`resources/items/item_database.csv` 에 행을 추가한다.  
`category` 열을 추가해 인벤토리 패널에서 탭 분류에 활용한다.

```
id,display_name,sell_price,category
dirt,흙,1,raw
stone,돌,2,raw
copper,구리,5,raw
iron,철,10,raw
silver,은,30,raw
gold,금,100,raw
dirt_brick,흙 벽돌,4,processed
stone_brick,돌 벽돌,8,processed
copper_ingot,구리 주괴,20,processed
iron_ingot,철 주괴,40,processed
silver_ingot,은 주괴,120,processed
gold_ingot,금 주괴,400,processed
```

`ItemDef.gd`에 필드 추가:

```gdscript
var category: StringName = &"raw"   # "raw" | "processed"
```

> `sell_price` 는 원자재 합산보다 높게 설정해 가공의 이점을 만든다.  
> 예: 초기 흙 1개(1$) → 벽돌 1개(4$) → 가공 이득 +3$  
> 효율 업그레이드 후 흙 1개(1$) → 벽돌 2개(8$) → 가공 이득 +7$

---

## 3. 기계 데이터 구조

### `MachineDef.gd` (신규)

```gdscript
class_name MachineDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## 기계가 한 번에 받을 수 있는 투입 자원 총 개수 (게이지 최대치)
@export var capacity: int = 10

## 작동 시간 (초). 게이지가 이 시간에 걸쳐 줄어든다.
@export var process_time: float = 5.0

## 투입 가능한 자원 id 목록 (빈 슬롯이면 전부 허용)
@export var accepted_inputs: Array[StringName] = []

## 투입 비율. { input_id → output_id, input_count → output_count }
## 예: 흙 3개 → 벽돌 1개
@export var recipes: Array[MachineRecipe] = []
```

### `MachineRecipe.gd` (신규)

```gdscript
class_name MachineRecipe
extends Resource

@export var input_id: StringName = &""
@export var output_id: StringName = &""

## 비율의 분모. 이 개수를 투입해야 output_per_unit 개가 나온다.
## 예) input_per_unit=1, output_per_unit=1 → 1:1 비율 (초기)
## 예) input_per_unit=1, output_per_unit=2 → 1:2 비율 (효율 업그레이드 후)
@export var input_per_unit: int = 1
@export var output_per_unit: int = 1
```

**출력량 계산 공식**

```
실제 투입 개수  = capacity                              (처리량 업그레이드로 증가)
처리 단위 수   = capacity / input_per_unit             (나머지는 버림)
실제 산출 개수  = 처리 단위 수 × output_per_unit
```

예시:
- 초기 (`capacity=1`, `input_per_unit=1`, `output_per_unit=1`): 흙 1 → 벽돌 1
- 처리량 업그레이드 후 (`capacity=3`, 비율 동일): 흙 3 → 벽돌 3
- 효율 업그레이드 후 (`capacity=3`, `input_per_unit=1`, `output_per_unit=2`): 흙 3 → 벽돌 6

### 업그레이드 두 축

| 업그레이드 | 변경 변수 | 효과 |
|-----------|----------|------|
| **처리량 증가** | `MachineDef.capacity` ↑ | 한 사이클에 더 많이 처리 |
| **효율 향상** | `MachineRecipe.output_per_unit` ↑ | 같은 투입으로 더 많이 산출 |

처리량과 효율은 **독립적**으로 업그레이드 가능하다.

| 업그레이드 단계 | capacity | input_per_unit | output_per_unit | 흙 → 벽돌 예시 |
|----------------|----------|---------------|----------------|----------------|
| 초기 | 1 | 1 | 1 | 흙 1 → 흙 벽돌 1 |
| 처리량 Lv.2 | 3 | 1 | 1 | 흙 3 → 흙 벽돌 3 |
| 효율 Lv.2 | 3 | 1 | 2 | 흙 3 → 흙 벽돌 6 |
| 처리량 Lv.3 + 효율 Lv.2 | 6 | 1 | 2 | 흙 6 → 흙 벽돌 12 |

### 초기 기계 두 종 레시피

| 기계 | 투입 → 산출 | 초기 비율 |
|------|------------|----------|
| 압착기 | 흙 → 흙 벽돌 | 1:1 |
| 압착기 | 돌 → 돌 벽돌 | 1:1 |
| 용광로 | 구리 → 구리 주괴 | 1:1 |
| 용광로 | 철 → 철 주괴 | 1:1 |
| 용광로 | 은 → 은 주괴 | 1:1 |
| 용광로 | 금 → 금 주괴 | 1:1 |

---

## 4. 기계 씬 구조 (Godot 노드)

```
MachineNode (Node2D)           ← scripts/hub/MachineNode.gd
├── Sprite2D                   ← 기계 외관
├── GaugeBar (ProgressBar)     ← 투입/작동 게이지
├── ClickArea (Area2D)         ← 기계 본체 클릭 감지 → 자원 투입 트리거
│   └── CollisionShape2D
├── LeverButton (Button)       ← 레버 클릭 → 작동 시작
└── Label                      ← 기계 이름 표시
```

> 씬 파일: `scenes/hub/MachineNode.tscn`  
> 스크립트: `scripts/hub/MachineNode.gd`  
> `OutputArea`(hover 수거)는 제거 — 완성품 수거가 자동 처리됨

---

## 5. 기계 상태 머신

```
IDLE  ──[기계 클릭]──▶  LOADING
                           │ (투입 가능한 재료 없으면 IDLE로 복귀)
                           │ 자원 인벤토리에서 즉시 차감
                           │ 게이지 차오름 — 초기: 즉시 반영 / C-3 이후: 아이템 날아오는 Tween
                           │
              ┌────────────┴────────────┐
   [capacity 100%]              [capacity 미달]
              ▼                          ▼
           FULL                       PARTIAL
   (게이지 100%, 레버 활성화)    (게이지 일부, 레버 활성화)
   자동 레버 업그레이드 트리거 ○   자동 레버 업그레이드 트리거 ✕
              │                          │
              └──────────┬───────────────┘
                  [레버 클릭]
                         │
                         ▼
                     RUNNING (게이지 줄어듦, 작동 중)
                         │ (process_time 경과)
                         ▼
                    DONE → collect_output() 자동 호출
                         │   hub_inventory에 완성품 추가
                         ▼
                       IDLE
```

### 상태 enum

```gdscript
enum MachineState {
    IDLE,      # 아무것도 없음
    LOADING,   # 게이지 차오르는 단계. 초기엔 즉시 채워짐, C-3 이후엔 Tween으로 채워짐
    FULL,      # capacity 100% 투입 완료. 레버 대기. 자동 레버 업그레이드 트리거 대상
    PARTIAL,   # capacity 미달 투입 완료. 레버 클릭은 가능, 자동 레버는 발동하지 않음
    RUNNING,   # 가공 중 (게이지 감소)
    DONE       # 가공 완료 — collect_output() 자동 호출 후 즉시 IDLE 복귀
}
```

---

## 6. `MachineNode.gd` 주요 변수 & 메서드

```gdscript
class_name MachineNode
extends Node2D

#region Variables
@export var m_def: MachineDef  # 인스펙터에서 연결

var m_state: MachineState = MachineState.IDLE
var m_gauge: float = 0.0        # 0.0 ~ 1.0

## 투입된 재료 추적. { input_id: StringName → units_loaded: int }
## units_loaded = 실제 투입된 input_per_unit 단위 수 (재료 개수 아님)
## 예) capacity=3, input_per_unit=1 → { &"dirt": 3 }
var m_loaded_items: Dictionary = {}

var m_run_timer: float = 0.0
#endregion

#region Public Methods

## ClickArea 클릭 시 호출. 비싼 산출품 레시피 우선으로 capacity만큼 그리디 투입.
## 투입 가능한 재료가 없으면 아무 동작 없음.
func try_load_from_hub() -> void

## 레버 클릭 시 호출. FULL 상태일 때만 RUNNING으로 전환.
func start_processing() -> void

## DONE 전환 시 자동 호출. m_loaded_items 기반으로 산출량 계산 후 hub_inventory에 추가.
func collect_output() -> void

#endregion
```

---

## 7. 게임플레이 흐름 상세

### 7-1. 투입 단계 (LOADING)

1. 플레이어가 **기계 클릭** (`ClickArea.input_event` 감지)
2. **레시피 우선순위 정렬**: 각 레시피의 `output_id` 판매가를 `ItemDatabase`에서 조회 → 내림차순 정렬 (비싼 산출품 우선)
3. **투입 가능 여부 확인**: 정렬된 레시피 중 `hub_inventory.get_count(input_id) >= input_per_unit` 인 레시피가 하나도 없으면 → **IDLE 유지**, 아무 동작 없음
4. 하나라도 있으면 → **`LOADING` 상태 전환**
5. **그리디(greedy) 투입** — `capacity`가 찰 때까지 우선순위 순서대로 투입:

```
remaining = capacity
for recipe in sorted_recipes:                       # 비싼 것 우선
    available_units = floor(hub_inventory.get_count(recipe.input_id) / recipe.input_per_unit)
    load_units     = min(floor(remaining / recipe.input_per_unit), available_units)
    if load_units > 0:
        hub_inventory.remove_item(recipe.input_id, load_units * recipe.input_per_unit)
        m_loaded_items[recipe.input_id] = load_units
        remaining -= load_units * recipe.input_per_unit
    if remaining <= 0:
        break
```

6. **`LOADING` 상태 유지** — 게이지 채우기 시작:
   - **초기 (C-3 이전)**: 자원 차감 즉시 게이지에 반영 (아이템이 날아오는 애니메이션 없이 바로 채워짐)
   - **C-3 이후**: 아이템 아이콘이 창고에서 기계 방향으로 날아오고, 도착 시마다 게이지 +1
7. 투입 결과에 따라 상태 분기:
   - 투입량이 `capacity` 100% → **`FULL` 상태 전환**
   - 투입량이 `capacity` 미달 (1유닛 이상) → **`PARTIAL` 상태 전환**

> **용량 미달 작동 허용 (옵션 4 정책)**  
> 복수 기계에 자원이 분산 투입되어도 각 기계는 투입된 만큼으로 레버 작동이 가능하다.  
> 예: 용량 5인 기계에 3개만 투입 → PARTIAL 전환, 레버 클릭 후 3유닛 분량만 산출.  
> 단, **자동 레버 업그레이드**는 `FULL` 상태일 때만 발동한다 — 100% 효율 보장을 위해.  
> `capacity`를 업그레이드할수록 한 사이클에 더 많이 처리해 효율이 높아지는 구조는 유지된다.

### 7-2. 작동 단계 (RUNNING)

1. 플레이어가 **레버 클릭** — `FULL` 또는 `PARTIAL` 상태일 때 모두 가능
2. `RUNNING` 상태 전환
3. `_process(delta)`에서 `m_run_timer` 증가
4. `GaugeBar`가 `process_time`에 비례해 감소
5. `m_run_timer >= m_def.process_time` 이면 → `DONE`

### 7-3. 수거 단계 (DONE)

1. `m_run_timer >= m_def.process_time` 도달 시 `DONE` 상태로 전환
2. **`collect_output()` 자동 호출** — 플레이어 조작 불필요
3. `m_loaded_items` 순회 → 각 레시피의 산출량 계산 후 `hub_inventory.add_item()`:

```
for input_id in m_loaded_items:
    var units: int = m_loaded_items[input_id]
    var recipe: MachineRecipe = _find_recipe_by_input(input_id)
    var output_count: int = units * recipe.output_per_unit
    hub_inventory.add_item(recipe.output_id, output_count)
```

4. `m_loaded_items` 초기화
5. `HubInventoryPanel.refresh()` 호출 (시그널로 Hub에 통보)
6. 기계 즉시 **`IDLE`로 복귀**

---

## 8. Hub 씬 전체 구조 (수정 후)

```
Hub (Node2D)                   ← scenes/hub/Hub.gd
├── UILayer (CanvasLayer)
│   ├── StartButton
│   ├── SkillTreeButton
│   ├── SkillTreePanel
│   ├── HubInventoryPanel      ← 창고(보관함) 표시 패널 (신규)
│   │   ├── ItemList           ← 아이템 목록
│   │   └── SellAllButton      ← 전량 판매 버튼
│   └── DollarsLabel           ← $0 표시
├── MachineArea (Node2D)       ← 기계들 배치 공간
│   ├── Compressor (MachineNode.tscn)   ← 압착기, 초기부터 존재
│   └── Furnace (MachineNode.tscn)      ← 용광로, 잠금 해제 필요
└── (기타 배경 Sprite)
```

---

## 9. Hub 인벤토리 패널 (HubInventoryPanel)

Hub 씬에서 창고 자원과 완성품(벽돌, 주괴)을 확인하고 판매할 수 있는 UI.  
**탭 분리 목록** 방식: 원자재 탭 / 가공품 탭으로 나누어 표시.

### 씬 구조

```
HubInventoryPanel (PanelContainer)      ← scenes/hub/ui/HubInventoryPanel.tscn
└── VBoxContainer
    ├── TabBar                           ← "원자재" | "가공품" 탭
    └── ScrollContainer
        └── ItemListContainer (VBoxContainer)   ← ItemRow들이 동적으로 추가됨
```

각 아이템 행은 재사용 가능한 서브씬:

```
ItemRow (HBoxContainer)                 ← scenes/hub/ui/ItemRow.tscn
├── TextureRect  (32×32)                ← 아이템 아이콘
├── Label        (이름)
├── Label        (×개수)
└── Button       ("판매")
```

### 동작 흐름

```
TabBar 탭 클릭
    └─ _refresh_list(selected_category)
           └─ ItemListContainer 자식 전부 queue_free()
           └─ hub_inventory.items 순회
                  └─ ItemDatabase.get_def(item_id).category == selected_category 인 것만
                  └─ ItemRow 인스턴스 생성 → setup(def, count) → add_child()
```

### 핵심 메서드 (`HubInventoryPanel.gd`)

```gdscript
## 탭 전환 또는 인벤토리 변경 시 목록 갱신
func _refresh_list(_category: StringName) -> void

## 전량 판매
func _on_sell_all_pressed() -> void:
    for item_id in GameState.hub_inventory.items.duplicate():
        var count: int = GameState.hub_inventory.get_count(item_id)
        var def: ItemDef = ItemDatabase.get_def(item_id)
        if def == null or def.sell_price <= 0:
            continue
        GameState.hub_inventory.remove_item(item_id, count)
        GameState.dollars += def.sell_price * count
    _refresh_list(m_current_category)
```

### `ItemRow.gd` 판매 버튼

```gdscript
func _on_sell_button_pressed() -> void:
    GameState.hub_inventory.remove_item(m_item_id, 1)
    GameState.dollars += m_sell_price
    ## 개수가 0이 되면 이 행 제거, 아니면 개수 레이블만 갱신
    if GameState.hub_inventory.get_count(m_item_id) <= 0:
        queue_free()
    else:
        m_count_label.text = "×%d" % GameState.hub_inventory.get_count(m_item_id)
```

---

## 10. 업그레이드 로드맵

처음엔 투입·레버가 수동이며, 달러를 투자해 단계별로 자동화한다.  
수거는 초기부터 자동 처리된다.

### 단계 0 — 초기

| 행동 | 방식 |
|------|------|
| 자원 투입 | 기계 클릭 |
| 작동 시작 | 레버 클릭 |
| 완성품 수거 | **자동** (가공 완료 시 즉시 hub_inventory 이전) |
| 판매 | 판매 버튼 클릭 |

### 단계 1 — 레버 자동화

> 업그레이드 이름: **자동 레버**

- `FULL` 상태가 되면 자동으로 `start_processing()` 호출
- 투입은 여전히 수동

### ~~단계 2 — 자동 수거~~ (기본 동작으로 통합)

수거는 초기부터 자동이므로 별도 업그레이드 단계 없음.

### 단계 2 — 자원 운반 로봇

> 업그레이드 이름: **운반 로봇**

- 일정 주기마다 자동으로 `try_load_from_hub()` 호출
- 기계를 클릭하지 않아도 창고에서 자동 투입

### 단계 3 — 컨베이어 벨트 (완전 자동화)

> 업그레이드 이름: **컨베이어 벨트**

- 투입 → 가공 → 수거 → 재투입이 끊김 없이 루프
- 판매만 수동 (또는 자동 판매 업그레이드 추가 가능)

### 업그레이드 플래그 (GameState에 추가 예정)

```gdscript
## 기계 자동화 플래그
var auto_lever: bool = false       # 단계 1
var auto_load_robot: bool = false  # 단계 2
var conveyor_belt: bool = false    # 단계 3
## auto_collect 불필요 — 수거는 기본 자동
```

---

## 11. 신규 파일 목록

| 파일 | 종류 | 역할 |
|------|------|------|
| `scripts/hub/MachineRecipe.gd` | Resource | 레시피 1줄 정의 |
| `scripts/hub/MachineDef.gd` | Resource | 기계 종류 정의 |
| `scripts/hub/MachineNode.gd` | Node 스크립트 | 기계 상태·게이지·레버 로직 |
| `scenes/hub/MachineNode.tscn` | 씬 | 기계 공통 씬 (Compressor / Furnace 공유) |
| `scripts/hub/ui/HubInventoryPanel.gd` | UI 스크립트 | 창고 패널, 탭 전환, 판매 버튼 |
| `scenes/hub/ui/HubInventoryPanel.tscn` | 씬 | 창고 패널 UI (TabBar + ScrollContainer) |
| `scripts/hub/ui/ItemRow.gd` | UI 스크립트 | 아이템 행 1줄 (아이콘·이름·개수·판매) |
| `scenes/hub/ui/ItemRow.tscn` | 씬 | 아이템 행 서브씬 |
| `resources/hub/machine_compressor.tres` | Resource | 압착기 MachineDef |
| `resources/hub/machine_furnace.tres` | Resource | 용광로 MachineDef |

### 기존 파일 수정

| 파일 | 변경 내용 |
|------|-----------|
| `resources/items/item_database.csv` | 벽돌, 주괴 등 가공 결과물 행 추가 |
| `autoload/GameState.gd` | `auto_lever`, `auto_collect` 등 자동화 플래그 추가 |
| `scenes/hub/Hub.tscn` | MachineArea, HubInventoryPanel 노드 추가 |
| `scenes/hub/Hub.gd` | 달러 표시 레이블, 기계 참조 연결 |

---

## 12. 구현 단계 계획

> 각 STEP은 독립적으로 완료·검증 가능한 최소 단위다.  
> 이전 STEP이 완료된 뒤 다음으로 넘어간다.

---

### Phase D — 인벤토리 패널 & 판매 UI

> **가장 먼저 구현.** 기계 없이도 보관함 확인 + 달러 획득 동선을 완성할 수 있다.

#### D-1. `item_database.csv`에 `category` 열 추가
- `resources/items/item_database.csv` 수정
  - 헤더에 `category` 열 추가
  - 원자재(`dirt`, `stone`, `copper`, `iron`, `silver`, `gold`) → `raw`
  - 가공품(`brick`, `*_ingot`) → `processed`
- 완료 기준: CSV 파일이 저장됨, 에디터 파싱 오류 없음

#### D-2. `ItemDef.gd`에 `category` 필드 추가
- `scripts/items/ItemDef.gd` 수정
- `var category: StringName = &"raw"` 한 줄 추가
- 완료 기준: 에디터 오류 없음

#### D-3. `ItemDatabase.gd` CSV 파서에 `category` 컬럼 읽기 추가
- `scripts/items/ItemDatabase.gd` 수정
- CSV 파싱 루프에서 `def.category = row["category"]` 할당 추가
- 완료 기준: `ItemDatabase.get_def(&"dirt").category == &"raw"` 런타임 확인

#### D-4. `ItemRow.tscn` 서브씬 제작 (에디터 작업)
- `scenes/hub/ui/` 폴더 생성
- 루트 `HBoxContainer` → 자식: `TextureRect`(32×32), `Label`(이름), `Label`(×개수), `Button`("판매")
- `scenes/hub/ui/ItemRow.tscn` 으로 저장
- 완료 기준: 씬 파일 저장됨, 에디터에서 노드 구조 확인

#### D-5. `ItemRow.gd` 작성
- `scripts/hub/ui/ItemRow.gd` 신규 생성
- `setup(def: ItemDef, count: int)` — 아이콘·이름·개수 세팅
- `ItemRow.tscn`에 스크립트 연결
- 완료 기준: 씬 단독 실행 시 이름·개수·버튼이 표시됨

#### D-6. `HubInventoryPanel.tscn` 씬 제작 (에디터 작업)
- 루트 `PanelContainer`
- 내부: `VBoxContainer` → `TabBar`(탭 2개: "원자재", "가공품") + `ScrollContainer` → `ItemListContainer(VBoxContainer)`
- `scenes/hub/ui/HubInventoryPanel.tscn` 으로 저장
- 완료 기준: 씬 파일 저장됨, 노드 구조 확인

#### D-7. `HubInventoryPanel.gd` 뼈대 작성
- `scripts/hub/ui/HubInventoryPanel.gd` 신규 생성
- `@onready` 로 `TabBar`, `ItemListContainer` 참조
- `HubInventoryPanel.tscn`에 스크립트 연결
- 완료 기준: 에디터 오류 없음

#### D-8. `_refresh_list()` 구현
- `TabBar.tab_changed` 시그널 연결 → `_refresh_list(selected_category)` 호출
- `ItemListContainer` 자식 전부 `queue_free()` 후
- `hub_inventory.items` 순회 → `def.category == selected_category` 인 것만 `ItemRow` 인스턴스 생성 후 `add_child()`
- 완료 기준: 탭 전환 시 원자재/가공품 목록이 교체됨 (테스트용 더미 아이템 수동 추가해서 확인)

#### D-9. `ItemRow` 판매 버튼 동작 구현
- `_on_sell_button_pressed()` 에서
  - `GameState.hub_inventory.remove_item(m_item_id, 1)`
  - `GameState.dollars += m_sell_price`
  - 개수가 0이 되면 `queue_free()`, 아니면 개수 레이블 갱신
- 완료 기준: 판매 버튼 클릭 시 `hub_inventory` 개수 감소 + `dollars` 증가

#### D-10. 전량 판매 버튼 추가
- `HubInventoryPanel.tscn`에 `Button`("전량 판매") 노드 추가
- `_on_sell_all_pressed()` — `hub_inventory` 전체 순회 → 판매 후 `_refresh_list()` 재호출
- 완료 기준: 버튼 클릭 시 목록이 비워지고 달러 증가

#### D-11. `DollarsLabel` 추가 및 갱신 연결
- `Hub.tscn`에 `Label`("$0") 노드 추가
- `Hub.gd`에 달러 레이블 참조 + `_update_dollars_label()` 함수 작성
- 판매 버튼 동작 이후, 귀환 직후 레이블 갱신
- 완료 기준: 달러 변화 시 레이블 숫자 즉시 반영

#### D-12. `Hub.tscn`에 `HubInventoryPanel` 배치 + 귀환 자동 갱신
- `Hub.tscn` UILayer에 `HubInventoryPanel` 노드 추가, 위치 배치
- `Hub.gd`의 `_ready()` 에서 `_refresh_list()` 초기 호출
- `transfer_run_to_hub()` 이후 패널 자동 갱신 트리거 연결
- 완료 기준: 채굴 후 귀환 → 원자재 탭에 흙 표시 → 판매 → 달러 증가 전체 흐름 동작

---

### Phase A — 기계 데이터 정의

> Phase D 이후. 기계를 붙이기 전에 데이터 구조를 먼저 정의한다.

#### A-1. `MachineRecipe.gd` 작성
- `scripts/hub/MachineRecipe.gd` 신규 생성
- 필드: `input_id`, `output_id`, `input_per_unit`, `output_per_unit`
- 완료 기준: `class_name MachineRecipe` 에디터 인식

#### A-2. `MachineDef.gd` 작성
- `scripts/hub/MachineDef.gd` 신규 생성
- 필드: `id`, `display_name`, `capacity`, `process_time`, `accepted_inputs`, `recipes: Array[MachineRecipe]`
- 완료 기준: `class_name MachineDef` 에디터 인식

#### A-3. `resources/hub/` 폴더 생성 + 압착기 데이터 파일 제작
- `resources/hub/machine_compressor.tres` 신규 생성
- `capacity=1`, `process_time=5.0`
- 레시피 2개 추가: `dirt`→`dirt_brick`(1:1), `stone`→`stone_brick`(1:1)
- 완료 기준: 에디터 인스펙터에서 데이터 확인

#### A-4. 가공 결과물 아이템이 `item_database.csv`에 있는지 확인
- `dirt_brick`, `stone_brick`, `copper_ingot`, `iron_ingot`, `silver_ingot`, `gold_ingot` 행 존재 여부 확인
- Phase D-1에서 이미 추가됨 → 별도 작업 불필요
- 완료 기준: `ItemDatabase.get_def(&"dirt_brick")` 이 null이 아닌 ItemDef 반환

---

### Phase B — 기계 씬 & 상태 머신

#### B-1. `MachineNode.tscn` 씬 뼈대 제작 (에디터 작업)
- 루트 `Node2D` → 자식 노드 구조:
  - `Sprite2D` — 기계 외관
  - `GaugeBar (ProgressBar)` — 투입·작동 게이지
  - `ClickArea (Area2D)` + `CollisionShape2D` — 기계 본체 클릭 감지
  - `LeverButton (Button)` — 작동 시작 버튼
  - `Label` — 기계 이름 표시
- `scenes/hub/MachineNode.tscn` 으로 저장
- 완료 기준: 씬 파일 저장됨, 에디터에서 노드 구조 확인

#### B-2. `MachineNode.gd` 뼈대 + 상태 enum 작성
- `scripts/hub/MachineNode.gd` 신규 생성
- `enum MachineState { IDLE, LOADING, FULL, RUNNING, DONE }` 정의
- `@export var m_def: MachineDef` 선언
- `MachineNode.tscn`에 스크립트 연결
- 완료 기준: 에디터 오류 없음, 인스펙터에서 `m_def` 슬롯 표시

#### B-3. 투입 로직 구현 (`IDLE → LOADING → FULL`)
- `ClickArea.input_event` 시그널 → `try_load_from_hub()` 연결
- 레시피를 `output_id`의 판매가 기준 **내림차순 정렬** (비싼 산출품 우선)
- 정렬 결과 **`capacity` 그리디 투입** (7-1 알고리즘 참고):
  - 어느 레시피도 재료 없으면 → IDLE 유지, 함수 종료
  - 있으면 → LOADING 전환 → 재료 차감 → 즉시 `FULL` 또는 `PARTIAL` 전환 (연출 없음)
    - 투입량 == capacity → `FULL`
    - 투입량 < capacity → `PARTIAL`
- 완료 기준: 기계 클릭 시 `hub_inventory` 자원 차감 + `FULL` 상태 전환 확인

#### B-4. 작동 로직 구현 (`FULL → RUNNING → DONE`)
- `_on_lever_clicked()` — `FULL` 상태일 때만 `RUNNING` 전환
- `_process(delta)` 에서 `m_run_timer` 증가, 게이지 감소
- `process_time` 경과 시 `DONE` 전환, 산출량 계산 (`capacity / input_per_unit * output_per_unit`)
- 완료 기준: 레버 클릭 → 게이지 감소 → `DONE` 상태 전환 확인

#### B-5. 수거 로직 구현 (`DONE → IDLE`)
- `DONE` 전환 시점에 `collect_output()` **자동 호출** (플레이어 입력 불필요)
- `m_loaded_items` 순회 → 각 레시피의 `output_per_unit` 적용 → `hub_inventory.add_item()`
- `output_collected` 시그널 emit → Hub가 받아 `HubInventoryPanel.refresh()` 호출
- `m_loaded_items` 초기화, 기계 `IDLE`로 복귀
- 완료 기준: 가공 완료 시 자동으로 `hub_inventory`에 완성품 추가 + 패널 갱신 확인

#### B-6. 게이지 바 시각 연동
- `ProgressBar.value` 를 `m_gauge * 100` 으로 매 프레임 갱신
- `RUNNING` 중 게이지 감소 시각 확인
- 완료 기준: 게이지 바가 상태에 따라 올바르게 채워지고 줄어듦

---

### Phase C — Hub 씬에 압착기 연결

#### C-1. `Hub.tscn`에 `MachineArea` 노드 추가
- `Hub.tscn` 에 `Node2D`(`MachineArea`) 추가
- `machine_compressor.tres` 를 연결한 `MachineNode` 인스턴스 배치
- 완료 기준: Hub 씬 실행 시 압착기가 화면에 표시

#### C-2. 압착기 클릭 이벤트 연결
- `MachineNode.gd`에 `_input_event` 또는 `Button` 클릭으로 `try_load_from_hub()` 연결
- 창고에 흙이 있을 때만 투입 동작
- 완료 기준: 흙 보유 시 클릭 → 차감 + 게이지 차오름

#### C-3. 자원 투입 Tween 연출 추가
- 투입 시 아이콘이 창고 위치에서 기계 방향으로 날아오는 `Tween` 구현
- 완료 기준: 연출이 재생되고 게이지가 올라감 (연출 없어도 로직은 동작)

#### C-4. 전체 흐름 통합 검증
- 흙 채굴 → 귀환 → 압착기 클릭 → 레버 → 벽돌 hover 수거 → 판매 → 달러 증가
- 완료 기준: 위 흐름이 끊김 없이 동작

---

### Phase E — 용광로 해금

#### E-1. `machine_furnace.tres` 생성
- `resources/hub/machine_furnace.tres` 신규 생성
- 레시피: 구리·철·은·금 → 각 주괴 (1:1)
- 완료 기준: 에디터 인스펙터 확인

#### E-2. `Hub.tscn`에 용광로 배치 (잠금 상태)
- `MachineArea`에 용광로 `MachineNode` 추가
- 초기 `visible = false` 또는 `locked` 상태로 배치
- 완료 기준: Hub 씬에서 용광로가 숨겨져 있음

#### E-3. 잠금 해제 조건 + UI
- `Hub.gd`에서 매 프레임 `GameState.dollars >= unlock_cost` 확인
- 조건 충족 시 "용광로 해금" 버튼 활성화
- 버튼 클릭 → `dollars` 차감 + 용광로 `visible = true`
- 완료 기준: 달러 조건 충족 → 버튼 활성 → 클릭 → 용광로 등장

---

### Phase F — 업그레이드 연동

#### F-1. `GameState.gd`에 자동화 플래그 추가
- `auto_lever`, `auto_load_robot`, `conveyor_belt` bool 변수 추가
- ~~`auto_collect`~~ — 수거가 기본 자동이므로 불필요
- 완료 기준: 에디터 오류 없음

#### F-2. 자동 레버 구현
- `MachineNode.gd` — **`FULL` 전환 시**에만 `GameState.auto_lever == true` 이면 즉시 `start_processing()` 호출
- `PARTIAL` 상태에서는 자동 레버 발동하지 않음 — 수동 클릭만 가능
- 완료 기준: 플래그 활성화 시 capacity 100% 달성 시에만 레버 클릭 없이 자동 작동

#### F-3. ~~자동 수거 구현~~ (기본 동작이 자동 수거이므로 제거)
- 수거는 B-5에서 이미 자동 처리됨. 별도 업그레이드 단계 불필요.

#### F-4. 운반 로봇 구현
- `MachineNode.gd` — `Timer`로 주기적으로 `try_load_from_hub()` 자동 호출
- `GameState.auto_load_robot == true` 일 때만 Timer 활성화
- 완료 기준: 플래그 활성화 시 기계 클릭 없이 자동 투입

#### F-5. 업그레이드 구매 UI 연결
- 기존 스킬 트리 또는 별도 `UpgradePanel`에서 플래그 활성화 버튼 추가
- 달러 비용 차감 후 플래그 `true` 설정
- 완료 기준: UI에서 구매 → 해당 자동화 동작 확인

---

## 13. 전체 STEP 요약표

| STEP | 작업 | 상태 |
|------|------|------|
| D-1 | `item_database.csv` `category` 열 추가 | ✅ |
| D-2 | `ItemDef.gd` `category` 필드 추가 | ✅ |
| D-3 | `ItemDatabase.gd` CSV 파서 `category` 읽기 | ✅ |
| D-4 | `ItemRow.tscn` 씬 제작 | ✅ |
| D-5 | `ItemRow.gd` 작성 + 씬 연결 | ✅ |
| D-6 | `HubInventoryPanel.tscn` 씬 제작 | ✅ |
| D-7 | `HubInventoryPanel.gd` 뼈대 작성 | ✅ |
| D-8 | `_refresh_list()` 탭 전환 구현 | ✅ |
| D-9 | `ItemRow` 판매 버튼 동작 | ✅ |
| D-10 | 전량 판매 버튼 추가 | ✅ |
| D-11 | `DollarsLabel` 추가 + 갱신 연결 | ✅ |
| D-12 | Hub 씬 배치 + 귀환 자동 갱신 | ✅ |
| A-1 | `MachineRecipe.gd` 작성 | 🔲 |
| A-2 | `MachineDef.gd` 작성 | 🔲 |
| A-3 | `machine_compressor.tres` 데이터 파일 제작 (`dirt→dirt_brick`, `stone→stone_brick`) | 🔲 |
| A-4 | `item_database.csv` 가공품 행 확인 (Phase D-1에서 완료) | ✅ |
| B-1 | `MachineNode.tscn` 씬 뼈대 제작 | 🔲 |
| B-2 | `MachineNode.gd` 뼈대 + 상태 enum | 🔲 |
| B-3 | 투입 로직 (`IDLE → FULL`) | 🔲 |
| B-4 | 작동 로직 (`FULL → DONE`) | 🔲 |
| B-5 | 수거 로직 (`DONE → IDLE`) | 🔲 |
| B-6 | 게이지 바 시각 연동 | 🔲 |
| C-1 | Hub 씬에 압착기 배치 | 🔲 |
| C-2 | 압착기 클릭 이벤트 연결 | 🔲 |
| C-3 | 자원 투입 Tween 연출 | 🔲 |
| C-4 | 전체 흐름 통합 검증 | 🔲 |
| E-1 | `machine_furnace.tres` 생성 | 🔲 |
| E-2 | Hub 씬에 용광로 배치 (잠금) | 🔲 |
| E-3 | 용광로 해금 조건 + UI | 🔲 |
| F-1 | `GameState` 자동화 플래그 추가 | 🔲 |
| F-2 | 자동 레버 구현 | 🔲 |
| F-3 | 자동 수거 구현 | 🔲 |
| F-4 | 운반 로봇 구현 | 🔲 |
| F-5 | 업그레이드 구매 UI 연결 | 🔲 |

---

## 14. 미결 사항

| 항목 | 현재 기본값 | 추후 결정 |
|------|-------------|-----------|
| 창고 자원 부족 시 부분 투입 처리 | **용량 미달도 작동 허용 (옵션 4 확정)** — 투입된 만큼 산출 | ✅ 확정 |
| 기계 복수 운영 (압착기 2대 등) | 미지원 | 업그레이드로 추가 가능 |
| 자원 투입 연출 속도 | 고정 | 후반에 빠르게 조정 가능 |
| 판매 단위 (개별 vs 전량) | 전량 판매만 | 개별 판매 UI 추가 가능 |
| 용광로 해금 달러 비용 | 미정 | 밸런싱 시 결정 |
| 자동 판매 업그레이드 | 없음 | 후반 자동화 트리에 추가 가능 |
| 기계 비주얼 에셋 | 플레이스홀더 | 전용 스프라이트 제작 시 교체 |

---

## 15. C-3 자원 투입 Tween 연출 — 구현 계획 (확정)

> 아래는 **즉시 투입 UI 없이 처음부터 Tween만** 사용하는 전제로 정리한 구현 계획이다. 기존 §7-1의 “C-3 이후 Tween” 문구는 본 절로 대체한다.

### 15-1. 데이터·시각 분리 원칙

| 구분 | 시점·의미 |
|------|-----------|
| **창고(`hub_inventory`)** | **클릭 즉시** `remove_item` — 플레이어가 보는 보관함 숫자는 바로 줄어든다. |
| **내부 적재량 (`m_loaded_count` 등)** | **클릭 즉시** 반영. `input_count`를 넘는 클릭·투입은 허용하지 않는다. |
| **게이지 (`m_gauge` + ProgressBar)** | **해당 클릭에 대응하는 Tween이 끝난 뒤**만 갱신한다. (도착 1회당 `+ 1 / input_count`) |
| **`FULL` 상태** | **`m_gauge`가 1.0에 도달한 직후**(= 마지막 아이콘이 도착한 뒤)로 정의한다. 내부 적재가 이미 꽉 찼어도, 아이콘이 아직 날아오는 동안은 `FULL`이 아니다. |
| **`PARTIAL` 상태** | 게이지가 0 초과·1 미만일 때(도착 완료된 단계 기준). 레버로 가공 시작 가능 여부는 기존 정책(부분 가동 허용)을 유지한다. |

### 15-2. `LOADING` 상태 활용 (선택적이지만 권장)

- **조건**: 내부 적재량이 `input_count`에 도달했으나, **아직 도착하지 않은 Tween이 남아** `m_gauge` &lt; 1.0인 구간.
- **의미**: “용량은 이미 다 찼지만, 자원이 아직 날아오는 중”을 표현한다.
- **입력**: 이 구간에서는 **추가 투입 클릭은 불가**(내부 카운트가 이미 상한). 레버는 기존과 같이 **PARTIAL에서도 가능**하면, 게이지만 따라가지 않은 상태에서는 레버 허용 규칙을 명시적으로 정한다(아래 15-6).

### 15-3. 연속 클릭·큐

- 플레이어가 빠르게 연속 클릭하면 **요청마다 독립적인 비행 아이콘**이 연속으로 재생된다(한 클릭당 아이콘 1개).
- **내부 적재 상한** 때문에, 상한 도달 이후 클릭은 무시한다.
- **PARTIAL**일 때는 기존과 동일하게 **이미 선택된 재료(`m_chosen_recipe`)만** 이어서 비행·투입한다.

### 15-4. 아이콘·경로

- **텍스처**: `ItemDatabase.get_def(input_id).icon` (현재 프로젝트에서는 공통 플레이스홀더 `image_32.png`와 동일해도 됨).
- **시작점**: **허브 인벤토리 패널(`HubInventoryPanel`)의 중심 근처**를 글로벌 좌표로 구한다. 패널에 `get_global_rect()` 기반 앵커 메서드를 두거나, Hub가 알고 있는 오프셋으로 보정한다.
- **도착점**: 해당 `MachineNode`(스프라이트 또는 ClickArea)의 글로벌 중심 근처.
- **좌표계**: UI(`Control`)와 `Node2D`가 섞이므로, **Hub의 `CanvasLayer` 아래에 전용 부모 노드**(예: `FxLayer` / 전체 화면 투명 `Control`)를 두고, 시작·끝을 **글로벌 좌표 → 해당 부모의 `CanvasItem.to_local()`** 로 변환해 Tween한다.

### 15-5. 씬·스크립트 역할 분담

| 담당 | 내용 |
|------|------|
| **`Hub.tscn` / `Hub.gd`** | `UILayer` 등 기존 `CanvasLayer` 하위에 **연출 전용 자식**(전체 화면 `Control` + 필요 시 `TextureRect` 풀 또는 즉시 생성)을 둔다. |
| **`HubInventoryPanel.gd`** | 패널 **중심 글로벌 좌표**(또는 `Rect2`)를 반환하는 public 메서드 제공. |
| **`MachineNode.gd`** | 투입 클릭 시: 검증 → 창고 차감·내부 카운트 증가 → **Hub에 “비행 요청” 시그널 또는 메서드 호출**(시작은 패널 앵커, 끝은 기계, 텍스처는 `ItemDef.icon`). Tween **완료 콜백**에서만 `m_gauge` 갱신 및 `PARTIAL`/`LOADING`/`FULL` 재판정. |
| **참조 연결** | Hub가 기계 노드를 `@onready`로 잡거나, 기계가 `_ready`에서 Hub를 그룹·경로로 찾아 비행 API를 호출한다. (결합도를 낮추려면 `MachineNode` → `hub_fx.request_fly(...)` 형태의 단일 진입점이 좋다.) |

### 15-6. 레버·자동 레버와의 정합

- **`FULL`**: 위 정의대로 **게이지 100% 도달(마지막 Tween 완료) 후**만 `FULL`로 전환한다.
- **`PARTIAL` 가동**: 기존처럼 게이지가 100% 미만이어도 레버로 가공을 시작할지 여부를 문서·코드에서 일치시킨다.  
  - **권장**: 레버는 “내부 적재량 &gt; 0 && RUNNING 아님”이면 활성(기존 UX 유지). 자동 레버(`auto_lever`)는 **`FULL`(게이지 100% 완료)일 때만** 발동 — 설계 문서 §10과 동일한 취지.
- **RUNNING 중**: 추가 투입 불가(기존과 동일).

### 15-7. `inventory_changed`와의 관계

- 창고 차감은 **클릭 즉시**이므로 `HubInventory.inventory_changed`로 패널이 갱신된다.
- 게이지는 Tween 완료 시점에만 변하므로, **패널 숫자와 게이지 진행이 어긋나 보이는 것은 의도된 연출**이다.

### 15-8. 구현 순서 (체크리스트)

1. Hub `CanvasLayer`에 연출용 부모 `Control` 추가 및 `Hub.gd`에 `play_item_fly(texture, global_from, global_to, on_finished: Callable)` API 구현 (`Tween` 또는 `Tween` 체인).
2. `HubInventoryPanel`에 `get_fly_start_global_position()` (또는 `Rect2` 중심) 추가.
3. `MachineNode`: 즉시 게이지 갱신 분기 제거 → 클릭 시 창고·내부 카운트 처리 후 Hub 비행 요청; 콜백에서 `m_gauge`·상태 전환.
4. 내부 적재 = `input_count`이고 미도착 Tween 존재 시 `LOADING` 전환 로직 추가(선택).
5. 연속 클릭·상한·PARTIAL 동일 재료 규칙 회귀 테스트.
6. 자동 레버가 **시각적 `FULL` 이후**에만 도는지 확인.

---

*이 문서는 Hub 가공 시스템 전용이다. 채굴 씬(Main) 설계는 `MVP_DEVELOPMENT_PLAN.md`, 인벤토리 시스템 상세는 `INVENTORY_ITEM_PLAN.md`를 참고.*

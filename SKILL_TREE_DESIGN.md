# 스킬트리 시스템 설계

Godot 4 기준. 이 문서는 스킬트리의 구조·규칙·데이터 설계만 정리한다.

참고 레퍼런스: Space Rock Breaker

---

## 1. 핵심 규칙

| 규칙 | 내용 |
|------|------|
| 초기 상태 | 루트 스킬 1개만 화면에 표시됨 |
| 스킬 공개 조건 | 선행 스킬을 1레벨 이상 배우면 연결된 후속 스킬이 새로 나타남 |
| 미공개 스킬 | 선행 스킬 미습득 시 해당 스킬은 트리에서 아예 보이지 않음 (흐릿 표시 아님) |
| 다중 레벨 | 하나의 스킬 노드는 여러 레벨을 가질 수 있음. 같은 노드를 반복해서 찍는 방식 |
| 레벨 순서 | 레벨은 반드시 순서대로만 올릴 수 있음 (1→2→3→…) |
| 복수 선행 조건 | 선행 스킬이 여러 개라면 AND 조건 — 모두 1레벨 이상이어야 공개됨 |

---

## 2. 스킬 노드 구조

### 2-1. SkillDef (스킬 정의 Resource)

스킬 하나를 정의하는 데이터.

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | `StringName` | 스킬 고유 식별자 (예: `"drill_damage"`) |
| `display_name` | `String` | UI에 표시할 이름 |
| `description` | `String` | 스킬 설명 |
| `max_level` | `int` | 최대 레벨. 1이면 단일 습득형, 2 이상이면 반복 강화형 |
| `cost_per_level` | `Array[SkillCost]` | 레벨별 필요 비용. 길이 = max_level |
| `effects` | `Array[SkillEffect]` | 이 스킬이 적용하는 스탯 효과 목록 |
| `prerequisites` | `Array[StringName]` | 공개 조건: 이 목록의 모든 스킬이 1레벨 이상이어야 함 (AND) |
| `unlocks` | `Array[StringName]` | 이 스킬을 1레벨 이상 배우면 공개되는 후속 스킬 id 목록 |
| `position` | `Vector2` | UI 트리에서 이 노드를 배치할 화면 좌표 (자유배치 방식) |

### 2-2. SkillCost (비용 구조)

하나의 레벨을 올리는 데 필요한 비용. 광석 단독, 달러 단독, 또는 둘 다 요구할 수 있다.
달러 획득/소비 시스템은 추후 구현 예정이므로, 현재는 모든 스킬의 `dollar_cost`를 0으로 설정한다.

| 필드 | 타입 | 설명 |
|------|------|------|
| `dollar_cost` | `int` | 필요한 달러($). 현재는 0으로 고정, 달러 시스템 구현 후 값 설정 |
| `ore_costs` | `Dictionary[StringName, int]` | 필요한 광석 종류와 수량. 빈 딕셔너리면 광석 불필요 |

SkillCost 자체는 레벨 하나의 최종 비용을 담는다. 레벨별 스케일링은 CSV의 base + growth 공식으로 계산된 뒤 `SkillDef.cost_per_level` 배열에 채워진다.

레벨 N 비용 공식:
```
dollar_cost = dollar_cost_base + dollar_cost_growth × (N - 1)
ore_amount  = ore_amount_base  + ore_amount_growth  × (N - 1)
```

CSV 컬럼 예시 (mine_damage 스킬, 5레벨):
```
dollar_cost_base=0, dollar_cost_growth=0, ore_id=dirt, ore_amount_base=3, ore_amount_growth=3

→ 레벨1: dirt×3  / 레벨2: dirt×6  / 레벨3: dirt×9  / 레벨4: dirt×12 / 레벨5: dirt×15
```

### 2-3. SkillEffect (스탯 효과)

스킬 하나가 적용하는 단일 스탯 효과. `effects` 배열로 여러 스탯을 동시에 올릴 수 있다.

효과 적용 방식: 덧셈. `최종값 = 기본값 + (value_per_level × current_level)`

| 필드 | 타입 | 설명 |
|------|------|------|
| `stat_id` | `StringName` | 변경할 스탯 식별자 (예: `"mine_damage_per_tick"`) |
| `value_per_level` | `float` | 레벨당 증가값 |

예시:
```
# "드릴 강화" 스킬이 채굴 대미지와 채굴 반경을 동시에 올리는 경우
effects: [
    { stat_id: "mine_damage_per_tick", value_per_level: 2.0 },
    { stat_id: "mine_radius",          value_per_level: 4.0 }
]

# mine_damage_per_tick 기본값이 5이고 위 스킬을 3레벨 찍었다면
# 최종값 = 5 + (2.0 × 3) = 11
```

---

## 3. max_level에 따른 동작 차이

| 항목 | max_level = 1 | max_level > 1 |
|------|---------------|----------------|
| 상태 표현 | 습득 / 미습득 (on/off) | 0 ~ max_level 사이의 정수 |
| 후속 스킬 공개 | 습득 시 즉시 | 레벨 1 달성 시 공개. 이후 레벨업은 공개에 영향 없음 |
| 비용 | `cost_per_level[0]` 단일 비용 | `cost_per_level[n-1]`로 레벨마다 비용이 달라질 수 있음 |
| 효과 적용 | `기본값 + value_per_level` | `기본값 + (value_per_level × current_level)` |

---

## 4. 스킬 공개 흐름

```
[게임 시작]
    │
    ▼
루트 스킬만 표시
    │
    ▼
플레이어가 스킬 1레벨 이상 습득
    │
    ▼
해당 스킬의 unlocks 목록 순회
    │
    ├── 각 후속 스킬의 prerequisites를 확인
    │       └── 목록의 모든 스킬이 1레벨 이상? (AND)
    │               ├── YES → 후속 스킬을 트리에 새로 표시
    │               └── NO  → 아직 숨김 유지
    │
    ▼
(반복)
```

---

## 5. 런타임 상태 (PlayerSkillState)

게임 진행 중 플레이어의 스킬 상태. `GameState` 또는 별도 Autoload에서 관리.

| 필드 | 타입 | 설명 |
|------|------|------|
| `learned_skills` | `Dictionary[StringName, int]` | `{ 스킬id: 현재레벨 }`. 미습득 스킬은 키 없음 |
| `visible_skills` | `Array[StringName]` | 현재 트리에 표시 중인 스킬 id 목록 |

세션 간 유지: 이 게임은 인크리멘털 장르이므로 기본적으로 저장·유지. prestige 시 명시적으로 초기화.

### 스킬 리셋

prestige(환생) 시스템 또는 디버그 목적으로 리셋 기능이 필요하다.

- `learned_skills`를 비우고 `visible_skills`를 루트 스킬만 남기면 초기 상태로 돌아감
- prestige 리셋 범위(스킬 + 자원 + 인벤토리 포함)는 prestige 설계 시 결정

---

## 6. 노드 위치 배치 방식 (자유배치)

각 `SkillDef`의 `position: Vector2`에 화면 좌표를 직접 지정하는 자유배치 방식을 사용한다.

- UI를 그릴 때 `position`을 기준으로 노드 버튼/패널을 배치
- 선행-후속 스킬 간 연결선은 두 스킬의 `position`을 이어 `draw_line`으로 그림
- 트리 전체 모양(세로형, 좌우 분기형 등)을 데이터에서 완전히 제어 가능

방사형(루트 중앙, 바깥으로 자동 확장)은 사용하지 않는다.

---

## 7. UI 트리 씬 구조

- 마우스 드래그로 트리 전체를 스크롤
- 마우스 휠로 확대/축소 (줌인·줌아웃)
- Godot 구현 방식: `SubViewport` 또는 `Control` 컨테이너 안에 트리를 두고, 입력 이벤트에서 `offset`과 `scale`을 조작

---

## 8. 스킬 노드 툴팁

스킬 노드에 마우스를 올리면 팝업 창이 표시된다.

### 툴팁 표시 내용

| 항목 | 설명 |
|------|------|
| 스킬 이름 | `display_name` |
| 현재 레벨 | `현재 레벨 / max_level` |
| 스킬 설명 | `description` |
| 비용 | 다음 레벨을 올리는 데 필요한 광석 목록과 수량 |
| 스탯 변화 | 각 effect마다 현재 수치와 업그레이드 후 수치를 나란히 표시 |

### 스탯 변화 표시 형식

업그레이드 시 변화하는 수치를 `현재값 → 다음값` 형식으로 표시한다.

```
채굴 대미지   9 → 10
채굴 반경     28 → 32
```

- 현재값: `StatSystem.get_final(stat_id)` — 현재 모든 스킬 효과가 적용된 최종 수치
- 다음값: `StatSystem.get_final(stat_id) + value_per_level` — 이 스킬을 한 레벨 더 올렸을 때의 최종 수치
- 스킬이 max_level이면 "최대 레벨" 메시지를 표시하고 수치 변화란은 숨김

### 미습득 스킬의 툴팁 (레벨 0인 경우)

현재값은 다른 스킬들의 효과만 반영된 최종 수치이고, 다음값은 거기에 이 스킬의 1레벨 효과를 더한 값이다.

```
채굴 대미지   5 → 6      ← 현재값은 다른 스킬들의 합산값, 다음값은 +value_per_level
```

---

## 9. 예시 스킬 트리 (구조 초안)

```
[드릴 기본] (루트, max_level=1)
    │
    ├──▶ [채굴 대미지 증가] (max_level=5)
    │        │
    │        └──▶ [광역 채굴 반경 증가] (max_level=3)
    │
    └──▶ [이동 속도 증가] (max_level=5)
             │
             └──▶ [연료 효율 향상] (max_level=3)
```

- 실제 스킬 구성·수치는 밸런스 단계에서 확정
- 위 트리는 구조 이해용 예시

---

## 10. 적용 대상 스탯 목록 (Drill.gd 기준)

스킬 효과(`SkillEffect.stat_id`)에서 참조할 수 있는 변수 목록.

| stat_id | 변수 | 의미 |
|---------|------|------|
| `"mine_damage_per_tick"` | `mine_damage_per_tick` | 채굴 대미지 |
| `"mine_radius"` | `mine_radius` | 채굴 반경 |
| `"mine_contact_radius"` | `mine_contact_radius` | 접촉 판정 반경 |
| `"mine_tick_interval"` | `mine_tick_interval` | 채굴 틱 주기 |
| `"move_speed_max"` | `move_speed_max` | 최대 이동 속도 |
| `"move_acceleration"` | `move_acceleration` | 가속도 |
| `"aim_angle_limit_deg"` | `aim_angle_limit_deg` | 조준 각도 제한 |
| `"aim_turn_max_deg_per_sec"` | `aim_turn_max_deg_per_sec` | 회전 속도 한도 |
| `"fuel_max"` | `fuel_max` | 최대 연료 |
| `"fuel_drain_per_second"` | `fuel_drain_per_second` | 연료 소모율 |

---

## 11. StatSystem — 스킬 효과 적용 방식

스킬 효과가 실제 게임에 반영되는 경로를 담당하는 시스템.
Autoload 싱글톤으로 두거나 `GameState` 안에 포함한다.

### 역할

- 각 스탯의 기본값(base)을 보관
- `PlayerSkillState.learned_skills`를 순회해 모든 스킬 보너스를 합산
- 최종값을 외부에 제공

### 최종값 계산 공식

```
최종값 = 기본값 + Σ(value_per_level × current_level)  [해당 stat_id를 가진 모든 스킬 효과 합산]
```

예시: `mine_damage_per_tick` 기본값 1, 스킬A(value_per_level=2, 레벨3), 스킬B(value_per_level=1, 레벨2)가 같은 스탯에 영향을 줄 때
```
최종값 = 1 + (2×3) + (1×2) = 9
```

### Drill.gd와의 연결

`Drill.gd`의 변수들은 기본값(base)만 유지한다.
실제 채굴·이동 로직에서 스탯을 사용할 때는 StatSystem에서 최종값을 조회한다.

```gdscript
# 스킬트리 도입 전
apply_damage(mine_damage_per_tick)

# 스킬트리 도입 후
apply_damage(StatSystem.get_final("mine_damage_per_tick"))
```

### 스킬 리셋(prestige) 시 동작

`learned_skills`를 비우면 모든 스탯의 보너스 합산이 0이 되어 자동으로 기본값으로 복귀한다.
`Drill.gd`의 변수를 건드릴 필요 없음.

---

## 12. 스킬트리 UI 구현 계획

### 씬 노드 구조

```
SkillTreePanel (PanelContainer) ← Hub.tscn에 이미 존재
└── VBox
    ├── HeaderBar (HBoxContainer)
    │   ├── PanelTitle (Label)
    │   └── CloseButton (Button)
    └── SkillTreeView (Control)       ← 스크롤/줌 입력을 받는 컨테이너
        ├── Canvas (Node2D)           ← 이 노드를 이동/스케일해서 스크롤/줌 구현
        │   ├── ConnectionsLayer (Node2D)  ← 연결선만 여기서 _draw
        │   └── NodesLayer (Control)       ← 스킬 노드 아이콘들이 여기에 배치
        └── Tooltip (PanelContainer)       ← 마우스를 따라다니는 팝업. 기본 hidden
```

### 생성할 파일

| 파일 | 역할 |
|------|------|
| `scenes/ui/skill_tree/SkillTreeView.tscn + .gd` | 스크롤/줌 입력 처리, 스킬 노드 생성, 연결선 갱신 |
| `scenes/ui/skill_tree/SkillNode.tscn + .gd` | 아이콘 버튼 1개. hover/click 이벤트 처리 |
| `scenes/ui/skill_tree/SkillTooltip.tscn + .gd` | 팝업 창 UI. 외부에서 데이터를 주입받아 표시 |

### SkillTreeView — 초기화 흐름

1. `_ready()`에서 `SkillDatabase.load_all()`로 전체 `SkillDef` 배열 로드
2. `GameState.visible_skills`를 읽어 현재 표시할 스킬 id 목록 확인
3. 표시 대상 스킬마다 `SkillNode` 인스턴스를 생성해 `NodesLayer`에 추가
   - 위치는 `SkillDef.position` 그대로 사용
4. `ConnectionsLayer.queue_redraw()` 호출해 연결선 그림

### SkillNode — 아이콘 노드

구성:
- `TextureButton` (아이콘 이미지)
- 레벨 표시용 `Label` (현재레벨/최대레벨, 아이콘 하단)

재화 상태에 따른 아이콘 색조:

| 상태 | 색조 |
|------|------|
| 업그레이드에 필요한 재화 부족 | 붉은 계열 |
| 업그레이드에 충분한 재화 있음 | 초록 계열 |
| 최대 레벨 | 회색 |

이벤트:
- `mouse_entered` → `Tooltip.show_for(skill_def, current_level)` 호출
- `mouse_exited` → `Tooltip.hide()` 호출
- `pressed` → 구매 시도 (비용 확인 → 차감 → 레벨업 → 후속 스킬 공개 갱신)

### ConnectionsLayer — 연결선

`_draw()`에서 `visible_skills`에 있는 스킬들을 순회:
- 각 스킬의 `prerequisites` 목록을 확인
- 선행 스킬도 `visible_skills`에 있으면 두 노드의 `position`을 이어 `draw_line` 호출
- 선 색상: 선행 스킬이 1레벨 이상 습득됐으면 밝은 색, 미습득이면 회색

### SkillTooltip — 팝업 창

마우스를 올린 스킬의 데이터를 받아 아래 내용을 표시:

```
[ 드릴 세기 업그레이드 ]         2 / 5 레벨

  드릴의 채굴 대미지를 높인다.

  비용: $3

  채굴 대미지   9 → 10
```

- 현재값: `StatSystem.get_final(stat_id)` (모든 스킬 포함 최종 수치)
- 다음값: `StatSystem.get_final(stat_id) + value_per_level`
- 최대 레벨이면 비용란과 스탯 변화란을 숨기고 "최대 레벨" 표시
- 위치: 마우스 커서 우측 하단에 붙되, 화면 밖으로 넘어가면 반대쪽으로 반전

### SkillTreeView — 스크롤/줌 입력

`_gui_input(event)` 에서 처리:
- 마우스 드래그 (좌클릭 홀드 + `InputEventMouseMotion`): `Canvas.position += event.relative`
- 마우스 휠 (`InputEventMouseButton` WHEEL_UP/DOWN): `Canvas.scale *= 1.1` or `0.9`
  - 줌 기준점은 마우스 커서 위치 (커서 아래 지점이 고정되도록)
  - 스케일 범위 제한: 0.3 ~ 2.0

### 스킬 구매 후 트리 갱신 흐름

```
구매 버튼 클릭
    │
    ▼
비용 충족 여부 확인 (GameState 자원 조회)
    │
    ├── 부족 → 툴팁에 "재료 부족" 표시 후 종료
    │
    └── 충족 → 자원 차감
                │
                ▼
           GameState.learned_skills[id] += 1
                │
                ▼
           레벨이 1이 됐으면 skill.unlocks 순회
           → 각 후속 스킬의 prerequisites AND 조건 확인
           → 충족된 스킬을 GameState.visible_skills에 추가
                │
                ▼
           SkillTreeView.refresh()
           → 새로 공개된 노드 인스턴스 생성 + ConnectionsLayer 갱신
```

### 구현 순서

각 단계는 수정 파일이 1~2개를 넘지 않도록 쪼갰다.

#### 1단계 — GameState 스킬 상태 변수 추가
수정 파일: `autoload/GameState.gd`
- `learned_skills: Dictionary` (`{ 스킬id: 현재레벨 }`) 변수 추가
- `visible_skills: Array[StringName]` 변수 추가
- `_ready()`에서 루트 스킬 id를 `visible_skills`에 초기값으로 넣기
- 검증: 게임 실행 후 `print(GameState.visible_skills)`로 루트 스킬이 보이는지 확인

#### 2단계 — SkillNode 씬 뼈대 생성
수정 파일: `scenes/ui/skill_tree/SkillNode.tscn`만 (스크립트 없음)
- `TextureButton` + 하단 `Label`(레벨 표시)로 구성된 씬 생성
- 스크립트 미연결, 레이아웃만 잡기
- 검증: 씬을 에디터에서 열어 노드 구조와 크기 확인

#### 3단계 — SkillNode 스크립트 작성
수정 파일: `scripts/ui/skill_tree/SkillNode.gd`만
- `setup(skill_def: SkillDef, current_level: int)` 함수 작성
  - `SkillDef.position`으로 노드 위치 설정
  - 레벨 라벨 텍스트 갱신 (`current_level / max_level`)
- 이벤트(hover, click) 없이 배치 로직만
- 검증: 씬에 연결 후 인스펙터에서 수동으로 `setup` 호출해 위치 확인

#### 4단계 — SkillTreeView 씬 뼈대 생성
수정 파일: `scenes/ui/skill_tree/SkillTreeView.tscn`만 (스크립트 없음)
- `Canvas(Node2D)` → `ConnectionsLayer(Node2D)` + `NodesLayer(Control)` 구조 생성
- 스크립트 미연결
- 검증: 씬을 에디터에서 열어 노드 계층 확인

#### 5단계 — SkillTreeView 로드 로직 작성
수정 파일: `scripts/ui/skill_tree/SkillTreeView.gd`만
- `_ready()`에서 `SkillDatabase.load_all()` 호출
- `GameState.visible_skills`에 있는 스킬만 `SkillNode` 인스턴스 생성 후 `NodesLayer`에 추가
- 연결선·스크롤·툴팁 없이 노드 배치만
- 검증: `print`로 로드된 스킬 수 출력, 화면에 노드가 올바른 위치에 표시되는지 확인

#### 6단계 — SkillTreeView를 Hub에 연결
수정 파일: `scenes/hub/Hub.tscn`, `scenes/hub/Hub.gd`
- `SkillTreePanel` 안의 `ContentLabel` 자리에 `SkillTreeView` 인스턴스 삽입
- `Hub.gd`에서 패널 열 때 `SkillTreeView.refresh()` 호출
- 검증: 거점 씬에서 스킬트리 버튼 클릭 시 노드가 보이는지 확인

#### 7단계 — ConnectionsLayer 연결선
수정 파일: `scripts/ui/skill_tree/SkillTreeView.gd`만 (또는 별도 `SkillTreeLines.gd`)
- `ConnectionsLayer._draw()`에서 visible 스킬들의 prerequisites 기반으로 선 그리기
- 검증: 선행-후속 스킬 사이에 선이 표시되는지 확인

#### 8단계 — 스크롤/줌 입력
수정 파일: `scripts/ui/skill_tree/SkillTreeView.gd`만
- `_gui_input()`에서 드래그(Canvas.position) + 휠(Canvas.scale) 처리
- 줌 범위 제한 (0.3 ~ 2.0)
- 검증: 마우스로 드래그/줌이 동작하는지 확인

#### 9단계 — SkillTooltip 씬 + 스크립트
수정 파일: `scenes/ui/skill_tree/SkillTooltip.tscn`, `scripts/ui/skill_tree/SkillTooltip.gd`
- 팝업 UI 레이아웃 구성
- `show_for(skill_def, current_level)` 함수: 이름/레벨/설명/비용/스탯변화 갱신
- 검증: 수동으로 `show_for` 호출해 데이터가 올바르게 표시되는지 확인

#### 10단계 — SkillNode에 hover 이벤트 연결
수정 파일: `scripts/ui/skill_tree/SkillNode.gd`만
- `mouse_entered` → `Tooltip.show_for(...)` 호출
- `mouse_exited` → `Tooltip.hide()` 호출
- 아이콘 색조 적용 (재화 부족: 붉은색 / 충분: 초록색 / 최대레벨: 회색)
- 검증: 노드에 마우스를 올렸을 때 툴팁이 올바른 위치에 표시되는지 확인

#### 11단계 — 스킬 구매 로직
수정 파일: `scripts/ui/skill_tree/SkillNode.gd`, `autoload/GameState.gd`
- `pressed` 이벤트에서 비용 확인 → 자원 차감 → `learned_skills` 갱신
- 레벨 1 달성 시 `unlocks` 순회 → prerequisites AND 조건 확인 → `visible_skills` 갱신
- `SkillTreeView.refresh()` 호출
- 검증: 스킬 구매 후 레벨 증가, 후속 스킬 노드가 새로 나타나는지 확인

---

## 13. 미결 사항 (prestige 설계 시 결정)

- [ ] prestige 리셋 범위 확정: 스킬 + 자원 + 인벤토리 포함 예정이나, prestige 시스템 설계 시 함께 결정

---

*이 문서는 설계 초안이며, 구현 진행에 따라 업데이트한다.*

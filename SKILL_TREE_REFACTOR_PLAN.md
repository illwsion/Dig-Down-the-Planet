# 스킬트리 리팩터링 계획

## 목표

CSV의 `pos_x`, `pos_y`, `prerequisites`, `unlocks` 컬럼을 제거하고,  
**씬 에디터에서 SkillNode를 배치하고 NodePath로 연결**하는 방식으로 전환한다.

- **CSV** → 스킬 효과·비용·이름·설명만 담음 (순수 데이터)
- **skill_tree.tscn** → 위치·연결 관계 담음 (레이아웃)

---

## 변경 전/후 구조 비교

```
[변경 전]
skill_database.csv
  id, display_name, ..., prerequisites, unlocks, pos_x, pos_y

SkillTreeView._ready()
  → SkillNode 씬을 동적으로 인스턴스화
  → node.position = skillDef.position

[변경 후]
skill_database.csv
  id, display_name, ..., effect_3_value  (끝)

skill_tree.tscn (씬 에디터에서 직접 배치)
  NodesLayer/
    SkillNode_DrillBasic   [m_skill_id="drill_basic",  m_prerequisite_nodes=[]]
    SkillNode_DrillDamage  [m_skill_id="drill_damage", m_prerequisite_nodes=[NodePath("SkillNode_DrillBasic")]]
    SkillNode_DrillSpeed   [m_skill_id="drill_speed",  m_prerequisite_nodes=[NodePath("SkillNode_DrillBasic")]]
    ...

SkillTreeView._ready()
  → 씬에 이미 배치된 노드들에 setup() 호출만 함
  → visibility 토글로 공개 여부 반영
```

---

## 단계별 작업

각 단계는 파일 1개만 수정하며, 독립적으로 검증 가능하게 쪼갰다.

---

### 1단계 — SkillDatabase.gd 파싱 코드 정리 + find_by_id() 추가

**수정 파일:** `scripts/skills/SkillDatabase.gd`

`prerequisites`, `unlocks`, `pos_x`, `pos_y` 파싱 코드를 제거하고,  
`c_TotalColumns`를 19 → 15로 수정한다.  
`find_by_id()` 정적 메서드를 추가한다.

```gdscript
const c_TotalColumns := 15

# _parse_row()에서 제거할 코드
# skill.position = Vector2(float(_row[17]), float(_row[18]))   ← 제거
# prereqRaw / unlocksRaw 파싱 블록 전체                        ← 제거

# 추가할 메서드
static func find_by_id(_id: StringName) -> SkillDef:
    for skill in load_all():
        if skill.id == _id:
            return skill
    return null
```

> **검증:** `print(SkillDatabase.find_by_id(&"drill_basic").display_name)` 가 `"드릴 기본"` 을 출력하는지 확인.

---

### 2단계 — SkillDef.gd 레이아웃 관련 필드 제거

**수정 파일:** `scripts/skills/SkillDef.gd`

`position`, `prerequisites`, `unlocks` 필드를 제거한다.  
1단계에서 SkillDatabase의 파싱 코드를 먼저 제거했으므로 컴파일 에러 없이 삭제 가능하다.

```gdscript
# 제거할 필드
var prerequisites: Array[StringName] = []
var unlocks: Array[StringName] = []
var position: Vector2 = Vector2.ZERO
```

> **검증:** 게임 실행 시 오류 없이 시작되면 성공.

---

### 3단계 — skill_database.csv 컬럼 4개 제거

**수정 파일:** `resources/skills/skill_database.csv`

`prerequisites`, `unlocks`, `pos_x`, `pos_y` 컬럼을 삭제한다.  
1단계에서 `c_TotalColumns`를 15로 맞춰뒀으므로 파싱 오류가 발생하지 않는다.

```
[변경 전 헤더]
id, display_name, description, max_level,
dollar_cost_base, dollar_cost_growth,
ore_id, ore_amount_base, ore_amount_growth,
effect_1_stat, effect_1_value,
effect_2_stat, effect_2_value,
effect_3_stat, effect_3_value,
prerequisites, unlocks, pos_x, pos_y   ← 이 4개 제거

[변경 후 헤더]
id, display_name, description, max_level,
dollar_cost_base, dollar_cost_growth,
ore_id, ore_amount_base, ore_amount_growth,
effect_1_stat, effect_1_value,
effect_2_stat, effect_2_value,
effect_3_stat, effect_3_value
```

> **검증:** `SkillDatabase.load_all()`이 오류 없이 스킬 5개를 반환하는지 확인.

---

### 4단계 — SkillNode.gd @export 필드 추가 및 setup() 변경

**수정 파일:** `scripts/ui/skill_tree/SkillNode.gd`

`m_skill_id`, `m_prerequisite_nodes`를 `@export`로 추가한다.  
`setup()`은 SkillDef를 외부에서 받는 대신, 내부에서 `SkillDatabase.find_by_id()`로 로드한다.  
position은 씬 에디터에서 설정하므로 `setup()`에서 건드리지 않는다.  
1단계에서 `find_by_id()`가 이미 추가되어 있으므로 호출 가능하다.

```gdscript
@export var m_skill_id: StringName
@export var m_prerequisite_nodes: Array[NodePath]

var m_skill_def: SkillDef
var m_current_level: int
var m_tooltip: Node


func setup(_tooltip: Node) -> void:
    m_tooltip = _tooltip
    m_skill_def = SkillDatabase.find_by_id(m_skill_id)
    if m_skill_def == null:
        push_error("SkillNode: skill_id를 찾을 수 없음 — %s" % m_skill_id)
        return
    m_current_level = GameState.learned_skills.get(m_skill_id, 0)
    m_icon_button.texture_normal = c_DefaultIcon
    m_icon_button.mouse_entered.connect(_on_mouse_entered)
    m_icon_button.mouse_exited.connect(_on_mouse_exited)
    m_icon_button.pressed.connect(_on_pressed)
    update_color()
```

> **검증:** `m_skill_id`가 비어있는 SkillNode를 씬에 추가했을 때 에러 메시지가 출력되는지 확인.

---

### 5단계 — skill_tree.tscn에 SkillNode 배치

**수정 파일:** `scenes/ui/skill_tree/skill_tree.tscn` (또는 해당 씬 파일)

씬 에디터에서 `NodesLayer`에 각 스킬별로 SkillNode 씬을 추가하고 배치한다.  
**이 단계가 핵심 작업이다.**

각 노드마다:
1. `m_skill_id` → Inspector에서 skill ID 입력 (예: `drill_basic`)
2. Position → 에디터에서 드래그 또는 Inspector에서 좌표 입력
3. `m_prerequisite_nodes` → Inspector에서 선행 SkillNode를 배열에 드래그

현재 5개 스킬 배치 예시:

| 노드 이름 | m_skill_id | m_prerequisite_nodes | 예시 위치 |
|-----------|-----------|----------------------|-----------|
| `SkillNode_DrillBasic` | `drill_basic` | (없음) | (0, 0) |
| `SkillNode_DrillDamage` | `drill_damage` | `[DrillBasic]` | (200, -100) |
| `SkillNode_DrillSpeed` | `drill_speed` | `[DrillBasic]` | (200, 100) |
| `SkillNode_InvAddSlot` | `inventory_slot_addslot` | `[DrillSpeed]` | (400, 0) |
| `SkillNode_InvMaxStack` | `inventory_slot_maxstack` | `[DrillSpeed]` | (400, 200) |

> **검증:** 씬을 열었을 때 에디터 뷰포트에서 스킬 노드 5개가 배치된 것이 보이는지 확인.

---

### 6단계 — SkillTreeView.gd 로직 교체

**수정 파일:** `scripts/ui/skill_tree/SkillTreeView.gd`

동적 인스턴스화를 제거하고, 씬에 이미 있는 노드들을 기반으로 동작하도록 교체한다.  
`_load_skill_defs()`, `_clear_nodes()` 메서드는 제거한다.

```gdscript
func _ready() -> void:
    _setup_skill_nodes()
    refresh()
    GameState.dollars_changed.connect(_refresh_colors)
    GameState.hub_inventory.inventory_changed.connect(_refresh_colors)


func _setup_skill_nodes() -> void:
    for node in m_nodes_layer.get_children():
        node.setup(m_tooltip)
        node.purchased.connect(_on_skill_purchased)


func refresh(_reset_position: bool = false) -> void:
    if _reset_position:
        m_canvas.position = size / 2.0
        m_canvas.scale = Vector2.ONE
    for node in m_nodes_layer.get_children():
        node.visible = GameState.visible_skills.has(node.m_skill_id)
    m_connections_layer.queue_redraw()


func _on_skill_purchased(_skillId: StringName) -> void:
    _check_new_unlocks()
    call_deferred("refresh")


func _check_new_unlocks() -> void:
    for skillNode in m_nodes_layer.get_children():
        if GameState.visible_skills.has(skillNode.m_skill_id):
            continue
        var allMet := true
        for nodePath in skillNode.m_prerequisite_nodes:
            var prereqNode = skillNode.get_node(nodePath)
            if GameState.learned_skills.get(prereqNode.m_skill_id, 0) < 1:
                allMet = false
                break
        if allMet:
            GameState.visible_skills.append(skillNode.m_skill_id)
```

> **검증:** 스킬트리를 열었을 때 `drill_basic`만 보이는지 확인.  
> `drill_basic` 구매 후 `drill_damage`와 `drill_speed`가 나타나는지 확인.

---

### 7단계 — SkillTreeLines.gd NodePath 기반으로 교체

**수정 파일:** `scripts/ui/skill_tree/SkillTreeLines.gd`

`SkillDef.prerequisites`와 `SkillDef.position` 대신,  
씬의 `SkillNode`를 직접 순회해 연결선을 그린다.  
`update_lines()` 메서드를 제거하고 `_draw()`만 사용한다.

```gdscript
@export var m_nodes_layer: NodePath


func _draw() -> void:
    var nodesLayer := get_node(m_nodes_layer)
    for skillNode in nodesLayer.get_children():
        if not skillNode.visible:
            continue
        for prereqPath in skillNode.m_prerequisite_nodes:
            var prereqNode = skillNode.get_node(prereqPath)
            if not prereqNode.visible:
                continue
            var prereqLearned: bool = GameState.learned_skills.get(prereqNode.m_skill_id, 0) >= 1
            var lineColor := c_ColorConnected if prereqLearned else c_ColorUnlearned
            draw_line(prereqNode.position, skillNode.position, lineColor, c_LineWidth)
```

Inspector에서 `m_nodes_layer`에 `NodesLayer` 노드를 연결한다.

> **검증:** 스킬트리에서 `drill_basic` → `drill_damage` 연결선이 그려지는지 확인.  
> `drill_basic` 구매 전 회색, 구매 후 흰색으로 바뀌는지 확인.

---

### 8단계 — SKILL_REFERENCE.md 업데이트

**수정 파일:** `resources/skills/SKILL_REFERENCE.md`

스킬 목록 테이블에서 `prerequisites`, `unlocks` 컬럼을 제거한다.  
CSV 컬럼 순서 섹션에서 마지막 4개 항목을 제거한다.  
새 스킬 추가 방법을 새 방식으로 교체한다.

```markdown
### 새 스킬 추가 방법

1. `skill_database.csv`에 스킬 데이터 행 추가 (이름, 설명, 비용, 효과)
2. `skill_tree.tscn`의 NodesLayer에 SkillNode 씬 인스턴스 추가
3. Inspector에서 `m_skill_id` 설정
4. 에디터에서 위치 드래그로 조정
5. `m_prerequisite_nodes` 배열에 선행 스킬 노드 드래그
```

> **검증:** 문서가 현재 구조를 정확히 반영하는지 확인.

---

### 9단계 — 엔드투엔드 검증

모든 단계 완료 후 전체 흐름을 통합 테스트한다.

1. Hub에서 스킬트리 열기 → `drill_basic`만 표시됨
2. `drill_basic` 구매 → `drill_damage`, `drill_speed` 공개됨
3. `drill_damage` 구매 → 툴팁 수치 정상 표시, 채굴 대미지 증가 확인
4. `drill_speed` 구매 → `inventory_slot_addslot`, `inventory_slot_maxstack` 공개됨
5. 씬을 나갔다 돌아와도 스킬 상태 유지됨

---

## 구현 체크리스트

- [ ] **1단계** — `SkillDatabase.gd` `find_by_id()` 추가 + 파싱 코드 정리 (c_TotalColumns → 15)
- [ ] **2단계** — `SkillDef.gd` `position`, `prerequisites`, `unlocks` 필드 제거
- [ ] **3단계** — `skill_database.csv` 컬럼 4개 제거 (`prerequisites`, `unlocks`, `pos_x`, `pos_y`)
- [ ] **4단계** — `SkillNode.gd` `@export` 필드 추가, `setup()` 시그니처 변경
- [ ] **5단계** — `skill_tree.tscn` 에디터에서 5개 스킬 노드 배치 및 NodePath 연결
- [ ] **6단계** — `SkillTreeView.gd` 동적 생성 → visibility 토글 방식으로 교체
- [ ] **7단계** — `SkillTreeLines.gd` NodePath 기반으로 교체
- [ ] **8단계** — `SKILL_REFERENCE.md` 새 스킬 추가 방법 업데이트
- [ ] **9단계** — 엔드투엔드 검증

---

*이전 문서: `SKILL_SYSTEM_INGAME_PLAN.md` (StatSystem 구현 완료)*

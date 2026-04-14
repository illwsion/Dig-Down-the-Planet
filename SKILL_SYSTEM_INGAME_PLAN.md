# 스킬 시스템 인게임 적용 계획

Godot 4 기준. 스킬트리 UI와 구매 로직은 완성된 상태이며, 이 문서는 스킬 효과를 실제 게임플레이 수치에 연결하는 작업을 다룬다.

---

## 현재 상태

### 완성된 것

| 항목 | 파일 |
|------|------|
| 스킬 데이터 모델 | `scripts/skills/SkillDef.gd`, `SkillCost.gd`, `SkillEffect.gd` |
| CSV 파서 | `scripts/skills/SkillDatabase.gd` |
| 스킬트리 UI | `scripts/ui/skill_tree/SkillTreeView.gd` (스크롤/줌/패닝) |
| 스킬 노드 | `scripts/ui/skill_tree/SkillNode.gd` (구매 로직, 비용 색상) |
| 툴팁 | `scripts/ui/skill_tree/SkillTooltip.gd` |
| 전역 상태 | `GameState.learned_skills`, `GameState.visible_skills` |
| 구매 흐름 | 비용 차감 → 레벨 증가 → 후속 스킬 공개 |

### 빠진 것 (핵심 미싱 레이어)

- **`StatSystem`** — 스킬 보너스를 실제 게임 수치에 합산해주는 중간 계층 없음
- **`Drill.gd`** — `mine_damage_per_tick`, `mine_radius` 등을 `@export` 기본값 그대로 사용 중. 스킬 구매해도 아무 변화 없음
- **`SkillTooltip`** — `+currentBonus → +nextBonus` 형식(보너스만)으로 표시 중. 설계 문서의 `기본값 + 보너스` 최종값 형식이 아님
- **`skill_database.csv`** — 스킬 2개뿐 (`drill_basic`, `drill_damage`)

---

## 핵심 아키텍처

```
Drill.gd @export vars   ←── 기본값(base)만 보관
        ↓  _ready()에서 register_base() 호출
StatSystem (Autoload)   ←── base + Σ(learned_skills × value_per_level) = 최종값
        ↑  get_final() 호출
Drill.gd 실제 로직      ←── StatSystem.get_final(&"mine_damage_per_tick") 등 사용
        ↑  get_final() 호출
SkillTooltip            ←── 현재값/다음값을 StatSystem 기준으로 표시
```

### 최종값 계산 공식

```
최종값 = 기본값 + Σ(value_per_level × current_level)  [해당 stat_id를 가진 모든 스킬 효과 합산]
```

---

## 단계별 작업

각 단계는 수정 파일 1~2개 이내로 제한하며, 단계마다 독립적으로 검증 가능하게 쪼갰다.

---

### 1단계 — StatSystem 뼈대 생성 + autoload 등록

**신규 파일:** `autoload/StatSystem.gd`
**수정 파일:** `project.godot`

`extends Node`만 있는 빈 파일을 만들고, `project.godot` autoload 섹션에 등록한다.

```ini
[autoload]
GameState="*res://autoload/GameState.gd"
ItemDatabase="*uid://pu7yyw7dhdcr"
StatSystem="*res://autoload/StatSystem.gd"
```

> **검증:** 게임 실행 시 오류 없이 시작되면 성공.

---

### 2단계 — StatSystem에 기본값 하드코딩

**수정 파일:** `autoload/StatSystem.gd`

`_ready()`에서 모든 스탯의 기본값을 `m_bases` 딕셔너리에 선언한다.
이 값은 Hub에서 스킬트리를 열 때(런 시작 전) 툴팁이 올바른 수치를 보여주기 위해 필요하다.

```gdscript
var m_bases: Dictionary = {}

func _ready() -> void:
    m_bases = {
        &"mine_damage_per_tick":      1.0,
        &"mine_radius":               50.0,
        &"mine_contact_radius":       10.0,
        &"mine_tick_interval":        1.0,
        &"move_speed_max":            400.0,
        &"move_acceleration":         400.0,
        &"aim_angle_limit_deg":       30.0,
        &"aim_turn_max_deg_per_sec":  54.0,
        &"fuel_max":                  100.0,
        &"fuel_drain_per_second":     5.0,
    }
```

> **검증:** `print(StatSystem.m_bases)` 로 10개 항목이 출력되는지 확인.

---

### 3단계 — StatSystem에 get_final() 구현

**수정 파일:** `autoload/StatSystem.gd`

스킬 데이터를 lazy load로 캐시하고, `get_final()`이 `base + Σ보너스`를 반환하도록 구현한다.

```gdscript
var m_skill_defs: Array[SkillDef] = []
var m_skill_defs_loaded: bool = false


func get_final(_stat_id: StringName) -> float:
    _ensure_skill_defs_loaded()
    var base: float = m_bases.get(_stat_id, 0.0)
    var bonus: float = 0.0
    for skillDef in m_skill_defs:
        var level: int = GameState.learned_skills.get(skillDef.id, 0)
        if level <= 0:
            continue
        for effect in skillDef.effects:
            if effect.stat_id == _stat_id:
                bonus += effect.value_per_level * level
    return base + bonus


func _ensure_skill_defs_loaded() -> void:
    if m_skill_defs_loaded:
        return
    m_skill_defs = SkillDatabase.load_all()
    m_skill_defs_loaded = true
```

> **검증:** Hub 스킬트리에서 `drill_damage` 스킬을 1레벨 구매한 뒤 `print(StatSystem.get_final(&"mine_damage_per_tick"))` 가 `2.0`을 출력하는지 확인.

---

### 4단계 — StatSystem에 register_base() 구현

**수정 파일:** `autoload/StatSystem.gd`

런 시작 시 Drill의 인스펙터 설정값으로 기본값을 덮어씌울 수 있도록 `register_base()`를 추가한다.

```gdscript
func register_base(_stat_id: StringName, _value: float) -> void:
    m_bases[_stat_id] = _value
```

> **검증:** 인스펙터에서 `mine_radius`를 80으로 바꾸고 런 시작 후 `print(StatSystem.get_final(&"mine_radius"))` 가 `80.0`을 출력하는지 확인.

---

### 5단계 — Drill.gd에서 StatSystem에 기본값 등록

**수정 파일:** `scripts/player/Drill.gd`

`_ready()` 끝에 `_register_stats()`를 호출해 인스펙터 설정값을 StatSystem에 전달한다.

```gdscript
func _ready() -> void:
    # ... 기존 코드 유지 ...
    _register_stats()


func _register_stats() -> void:
    StatSystem.register_base(&"mine_damage_per_tick",    mine_damage_per_tick)
    StatSystem.register_base(&"mine_radius",              mine_radius)
    StatSystem.register_base(&"mine_contact_radius",      mine_contact_radius)
    StatSystem.register_base(&"mine_tick_interval",       mine_tick_interval)
    StatSystem.register_base(&"move_speed_max",           move_speed_max)
    StatSystem.register_base(&"move_acceleration",        move_acceleration)
    StatSystem.register_base(&"aim_angle_limit_deg",      aim_angle_limit_deg)
    StatSystem.register_base(&"aim_turn_max_deg_per_sec", aim_turn_max_deg_per_sec)
    StatSystem.register_base(&"fuel_max",                 fuel_max)
    StatSystem.register_base(&"fuel_drain_per_second",    fuel_drain_per_second)
```

> **검증:** 런 시작 후 `StatSystem.get_final(&"mine_damage_per_tick")` 이 인스펙터의 `mine_damage_per_tick` 값과 일치하는지 확인.

---

### 6단계 — Drill.gd 채굴 로직 → StatSystem 연결

**수정 파일:** `scripts/player/Drill.gd`

채굴에 직접 영향을 주는 3개 함수의 변수를 StatSystem 조회로 교체한다.
`mine_tick_interval`은 0 이하로 내려가지 않도록 `maxf(..., 0.05)` 클램프를 추가한다.

| 함수 | 변경 전 | 변경 후 |
|------|---------|---------|
| `_process_mining_tick` (157번) | `mine_tick_interval` × 2곳 | `maxf(StatSystem.get_final(&"mine_tick_interval"), 0.05)` |
| `_process_mining_tick` (159번) | `mine_radius` | `StatSystem.get_final(&"mine_radius")` |
| `_process_mining_tick` (159번) | `mine_damage_per_tick` | `StatSystem.get_final(&"mine_damage_per_tick")` |
| `_update_drill_status` (168번) | `mine_contact_radius` | `StatSystem.get_final(&"mine_contact_radius")` |

> **검증:** `drill_damage` 스킬 3레벨 구매 후 런에 진입해 블록이 더 빨리 파괴되는지 확인. HUD의 `dmg` 디버그 출력도 함께 확인.

---

### 7단계 — Drill.gd 이동 로직 → StatSystem 연결

**수정 파일:** `scripts/player/Drill.gd`

이동·조준에 영향을 주는 변수들을 StatSystem 조회로 교체한다.

| 함수 | 변경 전 | 변경 후 |
|------|---------|---------|
| `_physics_process` (101번) | `move_speed_max` | `StatSystem.get_final(&"move_speed_max")` |
| `_physics_process` (107번) | `aim_angle_limit_deg` | `StatSystem.get_final(&"aim_angle_limit_deg")` |
| `_physics_process` (109번) | `aim_turn_max_deg_per_sec` | `StatSystem.get_final(&"aim_turn_max_deg_per_sec")` |
| `_physics_process` (117번) | `move_acceleration` | `StatSystem.get_final(&"move_acceleration")` |

> `@export` 변수들은 그대로 유지한다. 인스펙터에서 기본값을 조정하는 용도로만 쓰이며, `_register_stats()`가 이 값을 StatSystem에 전달한다.

> **검증:** 인스펙터에서 `move_speed_max`를 400 → 600으로 변경하고 런에서 이동 속도가 빨라지는지 확인. HUD 속도 디버그 수치도 함께 확인.

---

### 8단계 — SkillTooltip 수치 표시 개선

**수정 파일:** `scripts/ui/skill_tree/SkillTooltip.gd`

`_update_effects()`에서 보너스 증분 표시(`+n → +n`)를 최종 수치 표시(`현재값 → 다음값`)로 교체한다.

```gdscript
# 변경 전
var currentBonus := effect.value_per_level * _currentLevel
var nextBonus    := effect.value_per_level * (_currentLevel + 1)
row.text = "%s  +%s → +%s" % [effect.stat_id, ...]

# 변경 후
var currentFinal := StatSystem.get_final(effect.stat_id)
var nextFinal    := currentFinal + effect.value_per_level
row.text = "%s  %s → %s" % [effect.stat_id, _format_number(currentFinal), _format_number(nextFinal)]
```

> **검증:** `drill_damage` 스킬 0레벨 상태에서 툴팁에 `mine_damage_per_tick  1 → 2` 가 표시되는지 확인. 스킬 구매 후에는 `2 → 3` 으로 바뀌는지 확인.

---

### 9단계 — skill_database.csv 스킬 추가

**수정 파일:** `resources/skills/skill_database.csv`

트리 구조:

```
drill_basic (루트, 1레벨, 무료)
    ├── drill_damage   → mine_damage_per_tick +1/레벨, 3레벨, dirt 비용
    │       └── drill_radius → mine_radius +10/레벨, 3레벨, dirt 비용
    └── drill_speed    → move_speed_max +30/레벨, 3레벨, dirt 비용
            └── drill_fuel  → fuel_max +20/레벨, 3레벨, dirt 비용
```

추가할 행:

| id | 효과 | max_level | 비용 | prerequisites | unlocks | pos |
|----|------|-----------|------|---------------|---------|-----|
| `drill_radius` | `mine_radius` +10/레벨 | 3 | dirt×3, 성장 3 | `drill_damage` | — | 300, 150 |
| `drill_speed` | `move_speed_max` +30/레벨 | 3 | dirt×3, 성장 3 | `drill_basic` | `drill_fuel` | -300, 0 |
| `drill_fuel` | `fuel_max` +20/레벨 | 3 | dirt×3, 성장 3 | `drill_speed` | — | -300, 150 |

기존 `drill_damage` 행의 `unlocks` 컬럼에 `drill_radius` 추가.
기존 `drill_basic` 행의 `unlocks` 컬럼에 `drill_speed` 추가.

> **검증:** 스킬트리에서 `drill_speed`가 `drill_basic` 왼쪽에 표시되고, 구매 후 `drill_fuel`이 공개되는지 확인.

---

### 10단계 — 엔드투엔드 검증

모든 단계 완료 후 전체 흐름을 통합 테스트한다.

1. Hub에서 스킬트리를 열어 `drill_damage` 툴팁 확인 → `mine_damage_per_tick  1 → 2` 표시
2. dirt를 충분히 가진 상태에서 `drill_damage` 1레벨 구매 → `drill_radius` 노드 새로 공개됨
3. `drill_damage` 3레벨까지 구매 → 툴팁에 "최대 레벨" 표시
4. 런 진입 → 채굴 대미지가 기본 1이 아닌 4(기본 1 + 스킬 보너스 3)로 적용됨
5. 귀환 → Hub 재진입 후에도 스킬 상태 유지됨

---

## 추가 고려 사항

### 스탯 등록 시점 문제

`Drill.gd._ready()`는 런 씬 진입 후에만 실행됨. Hub에서 스킬트리를 열 때 StatSystem에 base값이 없을 수 있음.

**해결 방향:** `StatSystem.gd`에 알려진 모든 스탯의 기본값을 하드코딩으로 미리 선언해둠. `register_base()`는 런 시작 시 Drill의 인스펙터 설정값으로 덮어씌우는 역할만 함.

```gdscript
# StatSystem._ready()에서 기본값 선언
func _ready() -> void:
    m_bases = {
        &"mine_damage_per_tick":     1.0,
        &"mine_radius":              50.0,
        &"mine_contact_radius":      10.0,
        &"mine_tick_interval":       1.0,
        &"move_speed_max":           400.0,
        &"move_acceleration":        400.0,
        &"aim_angle_limit_deg":      30.0,
        &"aim_turn_max_deg_per_sec": 54.0,
        &"fuel_max":                 100.0,
        &"fuel_drain_per_second":    5.0,
    }
```

이렇게 하면 런 밖(Hub)에서도 툴팁이 올바른 기본값 기준 수치를 보여줌.

### 스킬 리셋(prestige) 대응

`GameState.learned_skills`를 비우면 `get_final()`의 bonus 합산이 자동으로 0이 되어 모든 스탯이 기본값으로 복귀함. Drill.gd 변수를 건드릴 필요 없음.

---

## 구현 체크리스트

- [ ] **1단계** — `autoload/StatSystem.gd` 뼈대 생성 + `project.godot` autoload 등록
- [ ] **2단계** — `StatSystem._ready()`에 스탯 기본값 하드코딩
- [ ] **3단계** — `StatSystem.get_final()` 구현 (스킬 보너스 합산)
- [ ] **4단계** — `StatSystem.register_base()` 구현
- [ ] **5단계** — `Drill.gd._register_stats()` 추가 + `_ready()` 연결
- [ ] **6단계** — `Drill.gd` 채굴 로직 (`_process_mining_tick`, `_update_drill_status`) → StatSystem 교체
- [ ] **7단계** — `Drill.gd` 이동 로직 (`_physics_process`) → StatSystem 교체
- [ ] **8단계** — `SkillTooltip.gd` `_update_effects()` 최종값 표시로 변경
- [ ] **9단계** — `skill_database.csv` 스킬 3개 추가 (`drill_radius`, `drill_speed`, `drill_fuel`)
- [ ] **10단계** — 엔드투엔드 검증 (Hub → 구매 → 런 → 효과 확인 → 귀환)

---

*참고 문서: `SKILL_TREE_DESIGN.md`, `MVP_DEVELOPMENT_PLAN.md`*

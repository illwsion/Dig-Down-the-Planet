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

예시:
```
# 광석만 필요 (현재 단계)
{ dollar_cost: 0, ore_costs: { "iron_ore": 5 } }

# 달러와 광석 둘 다 필요 (달러 시스템 구현 후)
{ dollar_cost: 200, ore_costs: { "crystal": 3, "iron_ore": 2 } }

# 달러만 필요 (달러 시스템 구현 후)
{ dollar_cost: 100, ore_costs: {} }
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
채굴 대미지   1 → 2
채굴 반경     20 → 24
```

- 현재값: `기본값 + (value_per_level × current_level)`
- 다음값: `기본값 + (value_per_level × (current_level + 1))`
- 스킬이 max_level이면 "최대 레벨" 메시지를 표시하고 수치 변화란은 숨김

### 미습득 스킬의 툴팁 (레벨 0인 경우)

```
채굴 대미지   1 → 2      ← 현재값은 기본값 그대로, 다음값은 1레벨 적용값
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

## 12. 미결 사항 (prestige 설계 시 결정)

- [ ] prestige 리셋 범위 확정: 스킬 + 자원 + 인벤토리 포함 예정이나, prestige 시스템 설계 시 함께 결정

---

*이 문서는 설계 초안이며, 구현 진행에 따라 업데이트한다.*

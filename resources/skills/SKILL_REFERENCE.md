# 스킬 레퍼런스

스킬을 추가하거나 `prerequisites` / `unlocks`를 작성할 때 참고하는 파일.
실제 데이터 원본은 `skill_database.csv`이며, 이 파일은 요약 참고용이다.

---

## 스킬 목록

| id | 표시 이름 | 설명 | max_level | 효과 stat_id | 효과량/레벨 | prerequisites | unlocks |
|----|-----------|------|:---------:|-------------|:-----------:|---------------|---------|
| `drill_basic` | 드릴 기본 | 드릴을 처음 얻는다 | 1 | — | — | — | `drill_damage` |
| `drill_damage` | 드릴 세기 | 채굴 대미지를 높인다 | 3 | `mine_damage_per_tick` | +1 | `drill_basic` | — |

---

## 스탯 ID 목록

스킬 효과(`effect_1_stat` 등)와 `StatSystem`에서 사용하는 stat_id 전체 목록.

| stat_id | 설명 | 기본값 |
|---------|------|-------:|
| `mine_damage_per_tick` | 채굴 틱당 대미지 | 1.0 |
| `mine_radius` | 채굴 감지 반경 (px) | 50.0 |
| `mine_contact_radius` | 접촉 즉시 채굴 반경 (px) | 10.0 |
| `mine_tick_interval` | 채굴 틱 간격 (초) | 1.0 |
| `move_speed_max` | 최대 이동 속도 | 400.0 |
| `move_acceleration` | 이동 가속도 | 400.0 |
| `aim_angle_limit_deg` | 조준 허용 각도 (도) | 30.0 |
| `aim_turn_max_deg_per_sec` | 최대 조준 회전 속도 (도/초) | 54.0 |
| `fuel_max` | 최대 연료량 | 100.0 |
| `fuel_drain_per_second` | 초당 연료 소모량 | 5.0 |

---

## 스킬트리 구조

```
drill_basic (0, 0)
├── drill_damage (100, 0)
```

---

## 새 스킬 추가 방법

1. 이 파일의 **스킬 목록** 테이블에 행 추가
2. `skill_database.csv`에 동일 내용을 CSV 형식으로 추가
3. 연결되는 기존 스킬의 `unlocks` 컬럼도 함께 수정

### CSV 컬럼 순서 (빠른 참조)

```
id, display_name, description, max_level,
dollar_cost_base, dollar_cost_growth,
ore_id, ore_amount_base, ore_amount_growth,
effect_1_stat, effect_1_value,
effect_2_stat, effect_2_value,
effect_3_stat, effect_3_value,
prerequisites, unlocks,
pos_x, pos_y
```

- `prerequisites` / `unlocks` 여러 개: `;` 로 구분 (예: `drill_basic;drill_damage`)
- 비용 없음: `dollar_cost_base`=0, `ore_id` 빈칸, `ore_amount_base`=0
- 효과 없음: `effect_1_stat` 빈칸

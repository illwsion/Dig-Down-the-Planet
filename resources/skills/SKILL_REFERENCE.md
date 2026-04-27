# 스킬 레퍼런스

스킬을 추가할 때 참고하는 파일.
실제 데이터 원본은 `skill_database.csv`이며, 레이아웃·연결 관계는 `SkillTreeView.tscn`의 SkillNode가 담당한다.

---

## 스킬 목록

| id | 표시 이름 | 설명 | max_level | 효과 stat_id | 효과량/레벨 |
|----|-----------|------|:---------:|-------------|:-----------:|
| `drill_basic` | 드릴 기본 | 드릴을 처음 얻는다 | 1 | — | — |
| `drill_damage` | 드릴 세기 업그레이드 | 채굴 대미지를 높인다 | 3 | `mine_damage_per_tick` | +1 |
| `drill_speed` | 드릴 속도 업그레이드 | 최대 속도를 높인다 | 3 | `move_speed_max` | +2 |
| `inventory_slot_addslot` | 인벤토리 슬롯 추가 | 인벤토리 슬롯을 늘린다 | 3 | `inventory_slot_count` | +1 |
| `inventory_slot_maxstack` | 인벤토리 슬롯 강화 | 슬롯당 아이템 보유량을 늘린다 | 3 | `inventory_max_stack` | +1 |

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
drill_basic
├── drill_damage
└── drill_speed
      ├── inventory_slot_addslot
      └── inventory_slot_maxstack
```

연결 관계(선행 스킬)와 위치는 `scenes/ui/skill_tree/SkillTreeView.tscn`의 각 SkillNode Inspector에서 확인·수정한다.

---

## 새 스킬 추가 방법

1. 이 파일의 **스킬 목록** 테이블에 행 추가
2. `skill_database.csv`에 동일 내용을 CSV 형식으로 추가
3. `SkillTreeView.tscn`의 NodesLayer에 SkillNode 씬 인스턴스 추가
4. Inspector에서 `m_skill_id` 설정
5. 에디터 뷰포트에서 위치 드래그로 조정
6. `m_prerequisite_nodes` 배열에 선행 스킬 노드 드래그

### CSV 컬럼 순서 (빠른 참조)

```
id, display_name, description, max_level,
dollar_cost_base, dollar_cost_growth,
ore_id, ore_amount_base, ore_amount_growth,
effect_1_stat, effect_1_value,
effect_2_stat, effect_2_value,
effect_3_stat, effect_3_value
```

- 비용 없음: `dollar_cost_base`=0, `ore_id` 빈칸, `ore_amount_base`=0
- 효과 없음: `effect_1_stat` 빈칸

# 행성 내부 드릴 파기 (Incremental) — MVP 개발 계획

Godot 4 기준. 이 문서는 설계·단계 계획만 정리하며, 코딩은 하지 않는다는 전제에 맞춤.

---

## 1. 게임 한 줄 요약

플레이어는 드릴을 업그레이드하며 그리드 타일 지형을 깎아 행성 내부로 무한히(세로) 내려가고, 채굴된 자원을 작은 인벤토리에 넣은 뒤 업그레이드로 성장하는 인크리멘털 게임.

---

## 2. MVP 범위 정의 (반드시 들어가는 것)

| 구분 | MVP에 포함 | MVP에서 제외(나중) |
|------|------------|---------------------|
| 지형 | 가로 32칸 고정, 세로 무한 스크롤(타일맵/청크 방식) | 바이옴, 이벤트 지형, 보스층 |
| 조작 | 클릭 시 아래 진행 시도, A/D로 좌·우 45° 진행 | 게임패드, 모바일 터치 최적화 |
| 채굴 | 타일 파괴 → 자원 획득 | 복합 광석, 희귀도, 체인 채굴 이펙트 |
| 인벤 | 2×2 슬롯, 슬롯당 3개까지 | 제작, 상점, 자동 정렬, 필터 |
| 성장 | 인벤 확장 등 1~2종 최소 업그레이드 | 풀 트리, 프레스티지, 다양한 드릴 모듈 |

MVP 완료 기준: “내려가며 채굴 → 자원이 인벤에 쌓임 → 업그레이드로 인벤이 커짐”이 끊기지 않고 10~15분 플레이 가능.

---

## 3. 기술 방향 (Godot 4)

- 지형: `TileMapLayer`(또는 프로젝트 구조에 맞는 TileMap) + 세로 방향 청크 생성/해제(무한에 가깝게).
- 드릴: 별도 `CharacterBody2D`(또는 `Area2D` + 이동 로직)로 타일과 충돌/레이캐스트로 채굴 판정.
- 데이터: 자원 종류·업그레이드 비용은 처음엔 딕셔너리/작은 Resource로도 충분; MVP 후 `Resource`/`Config`로 정리.
- 인벤: `Array` 또는 간단한 커스텀 클래스로 슬롯·스택 표현; UI는 `GridContainer` + 슬롯 씬.

(스크립트 언어는 팀이 GDScript/C# 중 선택했다면, 아래 파일 확장자만 `.gd` ↔ `.cs`로 치환하면 됨.)

---

## 4. 단계별 MVP 계획

각 단계마다 만들 파일(제안)과 체크리스트를 순서대로 진행하는 것을 권장.

---

### 단계 0 — 프로젝트 뼈대

목표: 씬 전환·입력·폴더 규칙만 잡고, 빈 화면에서 다음 단계로 넘어갈 수 있게 함.

만들 파일(제안)

- `project.godot` (이미 있으면 설정만)
- `scenes/main/Main.tscn` + `scenes/main/Main.gd`
- `autoload/GameState.gd` (선택: 전역 게임 상태·골드 등)
- 폴더: `scenes/`, `scripts/`, `assets/tiles/`, `resources/`

체크리스트

- [ ] Godot 4 프로젝트 해상도·픽셀 스냅(필요 시) 설정
- [ ] 메인 씬을 `Main.tscn`으로 지정
- [ ] 입력 맵: `move_left`(A), `move_right`(D), `drill_down`(마우스 왼쪽 또는 별도 액션)
- [ ] 간단한 카메라가 `Main` 자식으로 따라갈 준비(다음 단계에서 드릴 타깃 연결)

---

### 단계 1 — 32×무한(세로) 그리드 프로토타입

목표: 가로 32칸 고정(가로 중앙 정렬), 세로로 타일이 끊기지 않고 이어지는 지형. 카메라는 드릴(또는 임시 마커) 아래로 스크롤.

프로젝트에 고정한 값 (참고)

- 타일 32×32px, 가로 32타일, 청크 세로 32타일 (`CHUNK_HEIGHT_TILES`).
- 가로 중앙: 청크 루트 X를 `-(32 × 32) / 2 = -512` 픽셀 등으로 두어 32칸 폭이 화면 중심에 오도록 맞춤.
- 타일셋: `resources/tileset/terrain_tileset.tres` + `assets/tiles/tile_dirt.png` (4×4 아틀라스).

하위 단계 (1-x) — 한 번에 다 하지 않고 순서대로 검증할 것.

| 단계 | 내용 | 상태 |
|------|------|------|
| 1-1 | 단일 청크 표시: `Chunk`(`TileMapLayer`)가 가로 32 × 세로 32 타일을 채움. 가로 중앙 정렬이 맞는지 확인. | 구현됨 |
| 1-2 | World + 세로 연결: `World`가 청크 여러 개를 세로로 배치하고, 경계가 끊기지 않는지 확인. (개발용) HUD로 깊이(m), FPS, 활성 청크 등을 표시. | 구현됨 |
| 1-3 | 동적 청크 로딩: `WorldGenerator`로 타일 결정 로직 분리 + 포커스(Y 기준)로 청크 스폰/해제. 0m 위(음수 y) 구간에는 청크가 생성되지 않게 제한. | 구현됨 |
| 1-4 | 마무리 점검: 짧게 내려갔다 올라오며 청크 누수/깜빡임 점검. (선택) 디버그 텍스트 정리. | 구현됨 |

만들 파일(제안)

- `scenes/world/World.tscn` + `scripts/world/World.gd`
- `scenes/world/Chunk.tscn` + `scripts/world/Chunk.gd` (청크당 높이 32타일)
- `resources/tileset/terrain_tileset.tres` (또는 에디터에서 TileSet 생성)
- `scripts/world/WorldGenerator.gd` (1-3에서 본격 사용: 깊이·좌표에 따른 타일/아틀라스 좌표)

체크리스트

- [ ] (1-1~1-2) 타일셋으로 지형이 보이고, 고정 폭 32·가로 중앙·청크 경계가 맞는지 확인
- [ ] (1-3) 청크 로딩: 포커스(Y 기준) 위·아래 청크만 유지, 먼 청크는 제거. 0m 위(음수 y) 구간에는 청크 생성 금지
- [ ] (1-4) 디버그·짧은 스트레스 테스트로 누수/깜빡임 없음
- [ ] (선택) 한 타일 = 한 그리드 칸 규칙을 `World` 주석 등에 한 줄로 고정

---

### 단계 2 — 드릴 조작/이동 (마우스 홀드 조준 + 전진)

목표: 마우스 왼쪽을 누르고 있는 동안 드릴이 전진하며, 마우스 방향을 따라 천천히 회전한다. 회전은 수직 아래 기준 ±30°로 제한하고, 회전 속도(초당 회전 제한)는 업그레이드로 확장할 수 있게 만든다.

전제 (1단계와 맞추기 / 현재 구현 기준)

- Godot 2D: Y는 아래로 증가. 드릴 “전진(forward)”은 수직 아래 기준으로 회전된 방향.
- 회전 제한: `aim_angle_limit_deg` (기본 30), 회전 속도: `aim_turn_max_deg_per_sec` (업그레이드 대상).
- 카메라는 드릴 자식으로 두되, 화면이 기울지 않게 로컬 회전 상쇄.
- 청크 로딩은 `World`가 드릴의 `global_position.y`를 기준으로 `sync_chunks`.

하위 단계 (2-x) — 순서대로 끊어서 구현·검증.

| 단계 | 내용 | 검증 포인트 |
|------|------|-------------|
| 2-1 | `Drill` 씬 뼈대: `CharacterBody2D` + 충돌 + 스프라이트. 드릴이 타일보다 앞에 보이게 `z_index`. 바디 원점(0,0)=드릴 끝 정렬. | 드릴이 보이고 카메라가 따라감. |
| 2-2 | 입력/회전/전진: 마우스 홀드 시에만 전진 + 마우스 방향으로 “천천히” 회전. ±30° 클램프 + 초당 회전 제한. 카메라 회전 상쇄. | 이동 방향/회전이 기대대로, 홀드 해제 시 정지·회전 정지. |
| 2-3 | 타일 충돌: 타일에 막히는지 확인(`move_and_slide`). MVP에서는 타일 충돌을 단순하게(타일별 StaticBody 등) 유지해도 됨. | 타일을 뚫지 않고, 끼임이 과하지 않음. |
| 2-4 | 디버그/튜닝: HUD로 깊이, FPS, 활성 청크, 조준각(홀드 ON/OFF) 확인. 이동 속도 슬라이더가 `Drill.move_speed`에 반영. | 3단계 채굴 붙이기 전 조작 안정. |

만들 파일(제안)

- `scenes/player/Drill.tscn` + `scripts/player/Drill.gd`
  - (선택) `resources/player/drill_stats.tres`: 이동/회전 업그레이드 준비용

체크리스트 (요약)

- [ ] (2-1) Drill 씬 + 끝점 정렬 + 카메라
- [ ] (2-2) 마우스 홀드 조준/회전 제한/전진 + ±30° 클램프
- [ ] (2-3) 타일 충돌 + `move_and_slide`
- [ ] (2-4) HUD/슬라이더/조준각 디버그

구현 순서 권장

1. 2-1 → 2-2 → 2-3 순으로 진행.
2. 채굴(3단계)로 넘어가기 전에 조작/충돌 튜닝을 2-4에서 마무리.

---

### 단계 3 — 채굴 반경·드릴 상태·타일 내구도·파괴·(임시) 자원

목표: 드릴 끝(tip)을 기준으로 `mine_radius`(채굴 후보)와 `mine_contact_radius`(접촉·정지 판정)를 쓰고, 둘을 디버그로 잠깐이라도 보이게 한다. 드릴에 `idle` / `moving` / `digging` 상태를 두고, 타일에는 내구도를 두어 틱마다 대미지를 주며 깨지는 연출 후 0이 되면 제거한다. 자원 인벤은 4단계까지 최소 훅만.

용어 정리

- 반경 두 개는 드릴(또는 공유 스탯 리소스)에만 둔다. 타일은 “반경”이 아니라 내구도·타일 종류·시각 단계만 가진다.
- `mine_contact_radius` 안에 “아직 깨지지 않은 채굴 대상 타일”이 있으면 접촉으로 본다(내구도>0, 빈 셀 제외).

드릴 스크립트 변수 네이밍 (통일)

- 접두: 채굴은 `mine_*`, 이동은 `move_*`, 연료는 `fuel_*`, 조준은 `aim_*`.
- 상한·최대값은 `*_max` 또는 `*_limit`처럼 접미로 구분 (`fuel_max`, `move_speed_max`).

| 이름 | 의미 |
|------|------|
| `mine_radius` | 채굴 AoE 반경(px). 틱마다 tip 기준 원 안 타일 후보. |
| `mine_contact_radius` | 닿음/정지 판정 반경(px). `digging` 전환용. |
| `mine_tick_interval` | 채굴 틱 주기(초). |
| `mine_damage_per_tick` | 틱마다 각 후보 타일에 가하는 대미지. |
| `move_speed` | 현재 목표 이동 속도(px/s). UI 등에서 갱신. |
| `move_speed_max` | 이동 속도 상한(px/s). 슬라이더·가속 목표의 천장. |
| `move_acceleration` | 가속도(px/s²). MVP에선 생략하고 즉시 속도도 가능. |
| `fuel` | 현재 연료. |
| `fuel_max` | 최대 연료. |
| `fuel_drain_per_second` | 초당 연료 소모(홀드 중 이동/채굴 시 소모 정책은 구현 시 하나로 고정). |
| `aim_angle_limit_deg` | 수직 아래 기준 최대 조준각(한쪽, 도). |
| `aim_turn_max_deg_per_sec` | 초당 회전 한도(도). |

`DrillStatus` (enum, 이름 예시)

| 값 | 의미 |
|------|------|
| `idle` | `drill_down` 미홀드. 이동·회전·채굴 틱 없음. |
| `moving` | 홀드 중 + `mine_contact_radius` 안에 채굴 대상 타일 없음 → 전진·회전(2단계 규칙). |
| `digging` | 홀드 중 + `mine_contact_radius` 안에 채굴 대상 타일 있음. 전진·회전 정지는 3-8에서 연결(그 전에는 이동이 남을 수 있음). |

핵심 규칙 (결정 사항)

- 채굴 틱은 `idle`이 아닐 때만 돈다: 즉 `moving`과 `digging` 둘 다에서 `mine_tick_interval`마다 `mine_radius` 안 후보에 `mine_damage_per_tick`을 적용한다. `idle`에서는 틱 없음.
- `mine_radius` 후보: tip 기준 원 안의 타일 셀 중, 내구도가 남은 채굴 대상만(빈 셀 스킵).
- `digging`일 때 전진·회전을 멈추는 것은 설계 목표이며, 구현은 3-8에서 연결한다. 그 전까지는 이동이 남아 있어도 3-4~3-7 검증에는 지장 없다.
- `moving`일 때는 이동하면서도 채굴 틱(3-5)으로 범위 안 타일 HP를 깎을 수 있다.
- 타일 내구도는 0보다 크면 “살아 있음”. 0 이하가 되면 TileMap 셀 제거 + 해당 타일 충돌 제거 + (선택) 자원 누적.

연료·업그레이드와의 충돌은 이 단계에서 최소만: 연료 0이면 `moving`/`digging` 자체를 막을지는 한 가지로 정한다.

만들 파일(제안)

- `scripts/player/DrillStatus.gd` (enum만) 또는 `Drill.gd` 내부 enum
- 블록 종류 데이터 테이블: 예) `scripts/world/BlockDef.gd` (`extends Resource`, `id`, `max_hp` 등) + `resources/world/block_table.tres` 한 개에 행 여러 개(지금은 흙만). 또는 `BlockTable.gd`가 `Array[BlockDef]`를 들고 프리로드.
- `Chunk`: 로컬 `Vector2i -> int` 현재 HP 딕셔너리. `_fill_tiles` 끝에서 솔리드 셀마다 풀 HP로 전부 채움(아래 3-4 계획).
- `scripts/mining/MiningSystem.gd` (또는 `Drill`+`World`/`Chunk` 호출로 시작 후 분리)
- `resources/items/item_database.tres` 또는 `scripts/items/ItemDef.gd` (최소: `id`, `display_name`, `stack_size_for_mvp`) — 3-7 훅용
- (선택) `scripts/world/TileBreakCoordinator.gd`: TileMap·충돌·내구도 맵 동시 갱신

권장(요약) — 파일을 최소로 시작할 때

- `DrillStatus`: 우선 `Drill.gd` 안의 `enum`. HUD·채굴 쪽에서도 재사용이 커지면 그때 `drill_status.gd` 등으로 분리.
- 블록·내구도: 종류별 `max_hp`는 Resource 테이블에만 둔다. `Chunk`는 셀별 현재 HP만 들고, 스폰 시 테이블에서 읽어 전 셀을 한 번에 채운다(지연 초기화 말고 전부 채움).
- 채굴 틱: 처음엔 `Drill`에서 타이머 후 `World`에 “월드 좌표·반경 기준 대미지” 요청. 틱·후보 수집·청크 경계가 한 파일에 길어지면 `MiningSystem.gd` 분리.
- `TileBreakCoordinator`: 3단계 초반은 생략. `Chunk`에 `apply_damage` / `break_cell`처럼 “타일맵 + 충돌 + HP 맵”을 한 번에 갱신하는 진입점만 둔다. 여러 청크·호출 경로가 꼬이면 중앙 코디네이터 검토.
- 3-7 자원 훅: 카운터만이면 `GameState` 변수 + 로그로도 충분. 종류별 아이템이 필요해질 때 `ItemDef` 리소스·`item_database.tres` 도입.

블록 종류·내구도 (3-4) — 구현 계획

- 데이터 테이블: Godot `Resource`로 블록 한 줄을 표현한다. 예: `BlockDef`에 `id` (StringName), `max_hp` (int), 필요 시 `display_name`. 여러 블록을 모은 `BlockTable` 리소스에 `entries: Array[BlockDef]` 또는 `block_table.tres` 하나에 여러 서브리소스로 흙·돌 행을 넣는다. MVP는 흙 한 행만 두고 `max_hp`만 조정해도 된다.
- 셀 → 블록 종류: `Chunk` 또는 공용 헬퍼에서 `block_id_for_cell(local: Vector2i) -> StringName` (또는 enum). 지금은 타일이 전부 흙이면 상수로 `dirt` 반환. 돌을 넣을 때는 `TileMapLayer.get_cell_tile_data`의 아틀라스/소스로 분기만 추가한다.
- HP 저장: `m_cell_hp: Dictionary` 키 `Vector2i`, 값 현재 HP. `_fill_tiles`에서 타일을 깐 뒤, 솔리드한 `(lx, ly)`마다 `m_cell_hp[Vector2i(lx, ly)] = block_table.max_hp_for(block_id_for_cell(...))`로 전부 채운다. 빈 셀은 딕셔너리에 넣지 않거나 0으로 두되, 조회 규칙은 한 가지로 고정한다.
- API 예: `get_cell_hp`, `set_cell_hp` 또는 `apply_damage(local, amount)`. 파괴(3-7) 시 타일 제거와 함께 해당 키 삭제.
- `World.has_mineable_tile_in_circle` / `Chunk.has_mineable_tile_at`는 “타일이 있고 현재 HP > 0”으로 맞춘다(3-3 `digging` 판정과 일치).

하위 단계 (3-x) — 한 번에 하기 버거우면 3-1→3-2→… 순으로 끊어서 검증.

하위 단계 (3-x) — 한 번에 하기 버거우면 3-1→3-2→… 순으로 끊어서 검증.

| 단계 | 내용 | 검증 포인트 |
|------|------|-------------|
| 3-1 | 상수·기준점: `mine_radius`, `mine_contact_radius`, `mine_tick_interval`, `mine_damage_per_tick`를 `Drill`에 두고, 모든 원·거리 계산의 기준은 tip 월드 좌표로 고정. | 인스펙터에서 숫자 바꿀 때 의미가 바로 보임. |
| 3-2 | 디버그 시각화: tip 기준으로 채굴 원·접촉 원을 임시로 그린다(`draw` 또는 전용 `Node2D`). 색을 다르게, `debug_draw_mine_radii` 같은 플래그로 끄기 쉽게. | 두 반경 크기·겹침이 한눈에 들어옴. |
| 3-3 | `DrillStatus` 갱신: 매 틱 또는 `_physics_process`에서 `idle`/`moving`/`digging` 전환. `digging` 판정은 `mine_contact_radius` 안에 내구도>0 타일이 있는지(후보 열거 후 존재 여부). HUD에 상태 문자열을 찍으면 디버깅에 유리. | 홀드 on/off·바위 접촉 시 상태가 기대대로. |
| 3-4 | 타일 내구도 저장: `BlockDef` 등 Resource 테이블로 종류별 `max_hp`를 정의. `Chunk`가 `Vector2i -> hp` 맵을 들고, 스폰 시 솔리드 셀마다 테이블에서 읽어 전부 풀 HP로 채운다. 지금은 흙만, 나중에 돌은 같은 테이블에 행 추가 + `block_id_for_cell` 분기. | 인스펙터에서 흙 `max_hp` 변경 시 스폰 HP가 따라감. |
| 3-5 | 원형 후보 + 틱 대미지: `mine_tick_interval` 타이머로, 상태가 `moving` 또는 `digging`일 때만 틱을 돌린다. 매 틱 `mine_radius` 안 타일에 `mine_damage_per_tick` 적용(타일 중심 또는 셀 코너 기준 거리는 구현에서 하나로 고정). `idle`에서는 틱 없음. | 이동 중·정지 파기 모두 HP가 줄어듦. |
| 3-6 | 깨짐 표현: HP 비율(또는 단계 인덱스)에 따라 TileMap atlas 좌표·모듈레이션·오버레이로 “점점 깨짐”. MVP는 2~3 단계만 있어도 됨. | 맷돌 전에 균열이 보임. |
| 3-7 | 파괴 처리: HP≤0이면 셀 제거, StaticBody 제거, 내구도 맵에서 삭제. 이어서 `GameState`에 파괴 카운터/로그(4단계 인벤 전 임시). | 통과·충돌 제거·카운터 증가가 한 세트로 동작. |
| 3-8 | 이동 로직과 상태 연결: `digging`이면 전진·회전 입력을 막고, `moving`이면 2단계 이동 유지. 채굴·파괴 루프(3-5~3-7)가 돈 뒤 마지막에 붙이면 조정하기 쉽다. | 멈춰 팔 때와 빈 공간 질주할 때 구분됨. |

구현 순서 권장 (단계 3, 문서 번호 기준)

1. 3-1 → 3-2: 반경 상수·tip 기준·디버그 원으로 크기 확정.
2. 3-3: `DrillStatus`만 HUD로 검증.
3. 3-4: 블록 Resource 테이블 + `Chunk`에 스폰 시 전 셀 HP 채움 + `block_id_for_cell`(지금은 흙 고정) + mineable 판정을 HP>0과 맞춤.
4. 3-5: `mine_tick_interval`·원형 후보·`mine_damage_per_tick`으로 HP 감소.
5. 3-6: HP 비율(또는 단계)에 따른 타일 시각.
6. 3-7: HP≤0 시 타일·충돌·HP 맵 정리 + `GameState` 등 임시 자원 훅.
7. 3-8: `digging`일 때 전진·회전 정지 연결.

체크리스트

- [ ] (3-1~3-2) tip 기준으로 `mine_radius` / `mine_contact_radius`가 디버그로 확인됨
- [ ] (3-3) `idle` / `moving` / `digging` 전환(HUD). 접촉 판정은 HP 반영 후(3-4) 최종 확인
- [ ] (3-4) 블록 테이블 + 청크 스폰 시 HP 전부 채움 + mineable이 HP>0과 일치
- [ ] (3-5) `moving`·`digging`에서만 채굴 틱, HP 감소(`idle`에서는 틱 없음)
- [ ] (3-6) HP에 따른 깨짐 표현
- [ ] (3-7) HP 0이면 타일·충돌 제거 + (임시) 자원 누적
- [ ] (3-8) `digging`에서 이동·회전 정지, `moving`에서는 2단계 이동 유지

---

### 단계 4 — 인벤토리: 2×2, 슬롯당 최대 3 (MVP 규칙 고정)

목표: 채굴 자원이 슬롯 규칙을 지키며 쌓임. 가득 찼을 때 처리(버림/채굴 불가)를 명시.

만들 파일(제안)

- `scripts/inventory/Inventory.gd` (슬롯 배열, `try_add`, `can_add`)
- `scenes/ui/InventoryPanel.tscn` + `scripts/ui/InventoryPanel.gd`
- `scenes/ui/InventorySlot.tscn` + `scripts/ui/InventorySlot.gd`
- (선택) `autoload/InventoryService.gd` 또는 `GameState`에 포함

체크리스트

- [ ] 그리드 2×2, 각 슬롯 최대 3 규칙을 코드 상수로 박기 (`INV_W`, `INV_H`, `MAX_PER_SLOT`)
- [ ] 같은 아이템끼리 스택, 다른 아이템은 빈 슬롯 필요
- [ ] 가득 참: 드릴은 계속 움직이되 채굴 보상만 막는지 / 채굴 자체를 막는지 하나로 결정
- [ ] UI에 현재 각 슬롯 수량 표시 (숫자만 있어도 MVP 충분)
- [ ] (선택) 툴팁/아이콘은 자원 1종 아이콘만

---

### 단계 5 — 업그레이드 1종: 인벤 확장 (최소 루프 완성)

목표: 자원을 소비해 인벤 크기 또는 슬롯당 용량 중 하나를 업그레이드. 인크리멘털 루프(채굴→보관→소비→성장) 완료.

만들 파일(제안)

- `scripts/upgrades/UpgradeId.gd` (enum 또는 클래스) — 최소 `INV_SLOTS` 또는 `STACK_SIZE`
- `resources/upgrades/upgrade_defs.tres` (비용: 어떤 아이템 몇 개)
- `scenes/ui/UpgradePanel.tscn` + `scripts/ui/UpgradePanel.gd`
- `scripts/GameBalance.gd` (선택: 비용 커브 상수)

체크리스트

- [ ] 업그레이드 전/후 인벤 규칙이 UI·로직에 동시 반영
- [ ] 비용 지불 시 인벤에서 차감(슬롯별 부분 차감 처리)
- [ ] 비용이 부족하면 버튼 비활성 또는 메시지
- [ ] 저장/로드는 MVP에서 선택 — 없으면 “세션 플레이”로 범위 고지

---

### 단계 6 — 폴리싱(여전히 MVP 안)

목표: 깨지기 쉬운 부분만 다듬어 데모 플레이 가능 수준.

만들 파일(제안)

- `scenes/ui/PauseOverlay.tscn` (선택)
- `scripts/DebugOverlay.gd` (선택: FPS, 깊이, 청크 수)
- `AUDIO_BUS_LAYOUT` 등 — 필요 시만

체크리스트

- [ ] 창 크기 변경·카메라 경계 이슈
- [ ] 장시간 하강 시 메모리/청크 누수 점검
- [ ] 치명 버그: 인벤 오버플로, 타일 중복 제거, 드릴 끼임
- [ ] 최소 튜토리얼 텍스트 3줄(화면 고정 또는 첫 팝업)

---

## 5. 파일 생성 순서 요약 (한눈에)

1. `Main` + 입력 맵  
2. 단계 1 하위: 1-1 단일 청크 → 1-2 `World` + 청크 2개·(선택) 카메라 패닝/깊이 표시 → 1-3 `WorldGenerator` + 동적 청크 → 1-4 `CameraTarget` 추적 → 1-5 디버그·점검  
3. 단계 2 하위: 2-1 Drill 씬·Main 배치 → 2-2 입력·의도 방향·무충돌 이동 → 2-3 TileMap 충돌·`move_and_slide` → 2-4 World·HUD 드릴 기준 → 2-5 스냅·동시 입력·경계 테스트  
4. 단계 3 하위: 반경·디버그 원 → `DrillStatus` → 블록 테이블·청크 HP 풀 채움 → 틱 대미지 → 깨짐 표현 → 파괴·자원 훅 → 말미에 이동·`digging` 정지(3-8)  
5. `Inventory` + 인벤 UI  
6. `Upgrade` UI + 비용 차감  
7. 디버그/일시정지/밸런스 스킵 없이 최소 점검  

---

## 6. 다음 문서에서 정하면 좋은 결정 사항 (코딩 전)

- 세로 무한에서 난이도/타일 분포를 깊이만으로 할지
- 45° 이동 시 대각선 한 칸이 한 틱에 1타일인지, 연속 이동인지
- 인벤 가득 참 처리 정책
- MVP 업그레이드가 슬롯 크기(3×4 등)인지 슬롯당 3→5인지 (하나만 먼저)

---

*이 계획은 MVP 기준이며, “드릴 스탯/자동 채굴/오프라인 이득” 등은 이후 확장 단계에서 추가하면 됨.*

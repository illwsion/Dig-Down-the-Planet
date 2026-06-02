# 연료 시스템 — 단계별 구현 계획

Godot 4 · `Dig Down the Planet`

기획 원본: [`FUEL_SYSTEM_DESIGN.md`](FUEL_SYSTEM_DESIGN.md)

---

## 구현 원칙

| 원칙 | 내용 |
|------|------|
| **1단계 = 1파일** | 각 단계에서 수정·생성하는 파일은 **정확히 하나**만 |
| **interval만 사용** | 채굴 주기는 `mine_tick_interval`(초/틱)만 사용. `mine_ticks_per_second` / tps stat·UI **도입 안 함** |
| **HUD는 초반** | 연료 소모 로직 붙이기 **전에** 게이지+숫자 UI를 배치·갱신까지 완료 |
| **단계마다 검증** | 다음 단계로 넘어가기 전에 해당 단계 검증 항목 통과 |

런 연료 리필은 **`enter_run()`(또는 Drill 초기화) 한 경로**로 통일한다.  
(`FUEL_SYSTEM_DESIGN.md` §2-2: 런 시작·허브 복귀 후 재출발·사망/포기 후 재시작 모두 풀탱크)

---

## 단계 요약

| 단계 | 파일 | 작업 요약 |
|:----:|------|-----------|
| 1 | `autoload/StatSystem.gd` | 연료 stat 기준값 전환 |
| 2 | `scripts/player/Drill.gd` | export·등록·초기 `fuel` |
| 3 | `scenes/main/Main.tscn` | 연료 HUD 레이아웃 (게이지+숫자) |
| 4 | `scenes/main/Main.gd` | HUD 값 갱신 |
| 5 | `scripts/player/FuelDepthCost.gd` | 깊이 테이블 (신규) |
| 6 | `scripts/player/Drill.gd` | 틱당 소모·고갈 트리거 |
| 7 | `Drill/Main/Plan 문서` | 입력 잠금 기반 종료 흐름 재정의 (7-1~7-4) |
| 8 | `scenes/ui/RunResultScreen.tscn` | A안 카드형 결과 UI 레이아웃 (사유/요약/재료) |
| 9 | `scripts/ui/RunResultScreen.gd` | 종료 사유·최대 깊이·런 시간·재료 바인딩 |
| 10 | `scenes/GameRoot.gd` | 종료 사유별 결과 화면 호출 + 허브/재시작 연결 |
| 11 | `resources/skills/SKILL_REFERENCE.md` | stat 문서 동기화 |
| 12 | `resources/skills/skill_database.csv` | 스킬 데이터 마이그레이션 |

---

## 1단계 — `autoload/StatSystem.gd`

**목표:** StatSystem 기본값을 연료 설계에 맞춘다.

**작업**

- [x] `fuel_drain_per_second` 항목 **제거**
- [x] `fuel_cost_per_mine_tick` 추가, 기본값 **2.0**
- [x] `fuel_max` 기본값 **10.0**으로 변경
- [x] `mine_tick_interval` 기본값 **1.0** (초기 밸런스: 약 5틱·5초; `fuel_max`/`fuel_cost`로 런 길이 조절)

**검증**

- [ ] 프로젝트 실행 시 Autoload 로드 에러 없음
- [ ] (임시) `get_final(&"fuel_cost_per_mine_tick")` → 2.0, `get_final(&"fuel_max")` → 10.0

---

## 2단계 — `scripts/player/Drill.gd`

**목표:** 드릴 인스펙터·`register_base`를 StatSystem과 일치시킨다.

**작업**

- [x] `@export var fuel_drain_per_second` 제거
- [x] `@export var fuel_cost_per_mine_tick: float = 2.0` 추가
- [x] `@export var fuel_max: float = 10.0`
- [x] `@export var mine_tick_interval: float = 1.0` (또는 `@export_range` 유지하며 기본값만 1.0)
- [x] `_register_stats()`에서 `fuel_cost_per_mine_tick` 등록, `fuel_drain_per_second` 제거
- [x] `_ready()`에서 `fuel = StatSystem.get_final(&"fuel_max")` 로 초기화

**검증**

- [ ] Drill 씬 인스펙터에 새 export 표시
- [ ] Main 진입 직후 `fuel`이 10(스킬 없을 때)에 가깝게 시작

---

## 3단계 — `scenes/main/Main.tscn`

**목표:** 연료 HUD **골격**만 추가 (로직 없음). 연료 시스템 동작 검증 전에 시각 요소 확보.

**작업**

- [x] `UILayer` 하위에 `FuelPanel` (`HBoxContainer`) 추가
- [x] `FuelBar` (`ProgressBar`) — `max=10`, `value=10`, `show_percentage=false`
- [x] `FuelLabel` — `"10 / 10"` 임시 텍스트
- [x] AimLabel 아래(y=200) 배치, Depth/FPS와 겹치지 않음

**검증**

- [ ] Main 실행 시 연료 패널이 화면에 보임
- [ ] 레이아웃 깨짐·노드 누락 없음 (값 갱신은 4단계)

---

## 4단계 — `scenes/main/Main.gd`

**목표:** 게이지 + 숫자 **실시간 갱신**.

**작업**

- [x] `@onready`로 Fuel `ProgressBar`, `Label` 참조
- [x] `_update_fuel_hud()` — `fuel_max`/`fuel` 갱신, 게이지·`%d / %d` 라벨
- [x] `_update_hud()`에서 호출
- [ ] 연료 부족 색 변경은 **이번 단계 범위 밖** (선택)

**검증**

- [ ] 런 시작 시 `10 / 10` 및 게이지 만충
- [ ] (6단계 이후) 연료 소모 시 숫자·세로 게이지가 함께 변함

---

## 5단계 — `scripts/player/FuelDepthCost.gd` (신규)

**목표:** 깊이 추가 비용 `cost_depth` — **구간 테이블**만.

**작업**

- [x] `class_name FuelDepthCost`
- [x] 하한 테이블: 0→0, 50→0.5, 100→1.0, 200→2.0
- [x] `static func get_additive(depth_m: float) -> float`

**검증**

- [ ] `get_additive(0)` → 0, `get_additive(120)` → 0.5, `get_additive(250)` → 2.0

> `.tres` Resource 분리는 **이 단계에서 파일 1개 규칙**상 하지 않음. 테이블을 스크립트 상수로 두고, 나중에 필요 시 별도 단계로 분리 가능.

---

## 6단계 — `scripts/player/Drill.gd`

**목표:** 채굴 틱마다 연료 소모 + 고갈 시 종료 신호.

**작업**

- [x] `_compute_fuel_cost_for_tick()` — `cost_base + FuelDepthCost.get_additive(depth_m)`
- [x] `_process_mining_tick()` — 소모 후 채굴, 부족 시 `fuel=0` + `run_end_fuel_depleted`
- [x] `m_fuel_depleted_emitted`로 시그널 중복 방지
- [x] `moving` / `digging`만 (idle 변경 없음)

**검증**

- [ ] 홀드 채굴 시 HUD 연료가 틱마다 감소 (간격 약 1초)
- [ ] 기본 수치 기준 **약 5틱 후** 고갈 (표면, 스킬 0)
- [ ] 고갈 시 채굴 대미지 더 이상 적용 안 됨

---

## 7단계 — 입력 잠금 방식으로 재정의

**목표:** 카메라/월드/드롭은 계속 진행하고, 플레이어 입력만 막아 연료 고갈 종료를 처리한다.

### 7-1) `scripts/player/Drill.gd`만 수정

**목표:** 입력 잠금 플래그를 도입해 `drill_down`만 무효화한다.

**작업**

- [ ] `m_input_locked: bool` 추가
- [ ] `set_input_locked(_locked: bool)` 메서드 추가
- [ ] `_physics_process` 입력 조건을 `not m_input_locked`와 함께 평가
- [ ] 잠금 상태에서 `_update_drill_status()`는 `IDLE` 유지

**검증**

- [ ] 잠금 시 드릴은 홀드 해제 상태처럼 자연 감속
- [ ] 채굴/연료 소모는 더 이상 진행되지 않음

### 7-2) `scenes/main/Main.gd`만 수정

**목표:** 고갈 처리에서 드릴 프로세스를 끄지 않고 입력만 잠근다.

**작업**

- [ ] `_on_run_end_fuel_depleted()`에서 `m_drill.process_mode = DISABLED` 제거
- [ ] 강제 정지(`velocity = Vector2.ZERO`) 제거
- [ ] 대신 `m_drill.set_input_locked(true)` 호출
- [ ] `_process()`의 조기 `return` 구조를 조정해 월드 진행을 막지 않음

**검증**

- [ ] 연료 고갈 후 드릴 조작은 불가, 월드는 계속 진행
- [ ] 드릴은 감속으로 멈추고 카메라가 자연스럽게 따라감

### 7-3) `scenes/main/Main.gd`만 추가 수정

**목표:** 결과 오버레이 등장 애니메이션을 추가하되 게임 로직은 멈추지 않는다.

**작업**

- [ ] 오버레이 페이드/슬라이드 Tween 추가
- [ ] `get_tree().paused`는 사용하지 않음
- [ ] 오버레이는 입력만 가로채고 뒤 시뮬레이션은 계속

**검증**

- [ ] 오버레이 등장 중에도 DropItem 낙하/흡입/픽업 지속
- [ ] 연료 고갈 직후 마지막 드롭 획득 가능

### 7-4) `FUEL_SYSTEM_IMPLEMENTATION_PLAN.md`만 수정

**목표:** 7단계 계획을 입력 잠금 기준으로 문서 동기화한다.

**작업**

- [x] 7단계를 7-1~7-4로 세분화
- [x] `PROCESS_MODE_DISABLED` 기반 문구 제거
- [x] 검증 항목을 “입력 잠금 + 월드 지속” 기준으로 교체

**검증**

- [ ] 7단계를 순서대로 따라가면 파일당 1단계 원칙이 유지됨

---

## 8단계 — `scenes/ui/RunResultScreen.tscn` (신규)

**목표:** A안(실전형 카드) 결과 화면 **UI 레이아웃**을 확정한다.

**작업**

- [ ] 루트: `CanvasLayer` 또는 full-screen `Control` + 반투명 배경
- [ ] 중앙 카드(`PanelContainer`) 구성:
  - `TitleLabel` (종료 사유 제목: `연료 고갈`/`거점 복귀`)
  - `SummaryDepthLabel` (`최대 깊이: XX.X m`)
  - `SummaryDurationLabel` (`런 시간: MM:SS`)
  - `ItemsTitleLabel` (`획득 재료`)
  - `ItemsList` (항목·개수 리스트)
- [ ] 버튼: `HubButton`(허브로 복귀), `RetryButton`(새 런 시작)
- [ ] 초기 `visible = false` (표시는 9·10단계)

**검증**

- [ ] 에디터에서 씬 단독 미리보기 시 레이아웃 정상
- [ ] 사유/요약/재료/버튼 노드 경로 확정

---

## 9단계 — `scripts/ui/RunResultScreen.gd` (신규)

**목표:** 결과 화면 데이터·버튼 시그널.

**작업**

- [ ] 종료 사유 enum 또는 문자열 정의 (`fuel_depleted`, `return_to_hub`)
- [ ] `show_results(end_reason, max_depth_m: float, run_duration_sec: float, items: Dictionary)` API
- [ ] 제목 매핑:
  - `fuel_depleted` → `연료 고갈`
  - `return_to_hub` → `거점 복귀`
- [ ] 요약 포맷:
  - `최대 깊이: %.1f m`
  - `런 시간: MM:SS`
- [ ] `items`를 항목/개수로 렌더링 (`아이템명 × 개수`, 비어 있으면 `(비어 있음)`)
- [ ] `signal hub_requested`, `signal retry_requested`
- [ ] 버튼 pressed → 각 signal emit
- [ ] `show()` / `hide()` API

**검증**

- [ ] 종료 사유별 제목이 올바르게 바뀜
- [ ] 최대 깊이/런 시간이 올바른 형식으로 표시됨
- [ ] 더미 재료 데이터가 항목·개수로 표시됨
- [ ] 버튼 클릭 시 signal 발생 (에디터 또는 임시 Main 연결)

---

## 10단계 — `scenes/GameRoot.gd`

**목표:** 종료 사유별 결과 화면 호출 → 허브 / 새 런 **최종 플로우**.

**작업**

- [ ] `RunResultScreen` 프리로드·인스턴스 (또는 Main 자식으로 이미 있으면 참조만)
- [ ] 런 시작 시점 기록(`run_start_time_ms` 등), 런 중 최대 깊이 추적(`max_depth_m`)
- [ ] 종료 이벤트 수신 시 `show_results(end_reason, max_depth_m, run_duration_sec, run_display)` 호출
- [ ] 종료 사유 분기:
  - 연료 고갈 시 `end_reason = fuel_depleted`
  - 수동 복귀 버튼 시 `end_reason = return_to_hub`
- [ ] `hub_requested` → `return_to_hub()`
- [ ] `retry_requested` → 기존 Main 제거 후 `enter_run()` (**풀탱크는 Drill `_ready` / `enter_run`에서 재적용**)
- [ ] `enter_run()` 시점에 런 상태·연료 초기화 경로가 한 번만 타는지 확인
- [ ] (선택) 사망·포기도 동일 결과 화면으로 합칠지 — 이번 단계 범위면 연료 고갈만

**검증**

- [ ] 연료 고갈 종료 시 제목이 `연료 고갈`로 표시됨
- [ ] 수동 복귀 종료 시 제목이 `거점 복귀`로 표시됨
- [ ] 두 종료 케이스 모두 최대 깊이/런 시간/획득 재료 표시 정확
- [ ] 결과 화면 → **허브** 정상
- [ ] 결과 화면 → **새 런** → 연료 10/10, 채굴 재개
- [ ] 허브 갔다가 다시 나와도 풀탱크

---

## 11단계 — `resources/skills/SKILL_REFERENCE.md`

**목표:** 문서와 코드 stat_id 일치.

**작업**

- [ ] `fuel_drain_per_second` 행 제거
- [ ] `fuel_cost_per_mine_tick` 추가 (기본 2.0)
- [ ] `fuel_max` 기본값 10.0으로 수정
- [ ] `mine_tick_interval` 기본값 1.0 명시 (tps 항목 없음)

**검증**

- [ ] 문서 stat 표와 `StatSystem` / `Drill` export 일치

---

## 12단계 — `resources/skills/skill_database.csv`

**목표:** 실제 스킬 데이터 마이그레이션.

**작업**

- [ ] 연료 관련 effect stat을 `fuel_cost_per_mine_tick`, `fuel_max`로 교체
- [ ] `drill_fuel` 등 `fuel_max` 보너스를 **초기 10 기준**으로 재조정 (예: +5/레벨)
- [ ] `fuel_drain_per_second` 참조 제거

**검증**

- [ ] Hub 스킬 구매 후 Main에서 `fuel_max` / 틱 소모 변화 반영
- [ ] 잘못된 stat_id로 인한 무시 효과 없음

---

## 완료 기준 (전체)

- [ ] `moving` / `digging` 채굴 틱마다 `fuel_cost_per_mine_tick + cost_depth` 소모
- [ ] 종료 사유별 제목(`연료 고갈`/`거점 복귀`) + 최대 깊이/런 시간/획득 재료 결과 화면
- [ ] 허브 복귀 / 새 런 / 재시작 모두 **풀탱크**
- [ ] HUD: 게이지 + `current / max` 숫자
- [ ] 채굴 주기: **`mine_tick_interval`만** (tps 미사용)
- [ ] 초기 밸런스: 스킬 0, 표면, interval 1s → 대략 **5초 내외** 고갈 체감 (`fuel_max`로 런 길이 확장)

---

## 진행 체크리스트

| 단계 | 파일 | 완료 |
|:----:|------|:----:|
| 1 | `autoload/StatSystem.gd` | ☑ |
| 2 | `scripts/player/Drill.gd` | ☑ |
| 3 | `scenes/main/Main.tscn` | ☑ |
| 4 | `scenes/main/Main.gd` | ☑ |
| 5 | `scripts/player/FuelDepthCost.gd` | ☑ |
| 6 | `scripts/player/Drill.gd` | ☑ |
| 7 | `Drill/Main/Plan 문서` | ☐ |
| 8 | `scenes/ui/RunResultScreen.tscn` | ☐ |
| 9 | `scripts/ui/RunResultScreen.gd` | ☐ |
| 10 | `scenes/GameRoot.gd` | ☐ |
| 11 | `resources/skills/SKILL_REFERENCE.md` | ☐ |
| 12 | `resources/skills/skill_database.csv` | ☐ |

---

## 참고: 설계 문서와의 대응

| 설계 (`FUEL_SYSTEM_DESIGN.md`) | 구현 단계 |
|-------------------------------|-----------|
| §1 확정 사항 (틱 소모·덧셈·고갈 종료) | 6, 7, 10 |
| §2 런 리필·풀탱크 | 2, 10 |
| §3 stat 기본값 10 / 2.0 | 1, 2 |
| §4 깊이 테이블 | 5, 6 |
| §6 런 결과 화면 | 8, 9, 10 |
| §7 interval만 (tps 없음) | 1, 2, 6 (변환 없음) |
| §8 HUD 게이지+숫자 | **3, 4** (초반) |

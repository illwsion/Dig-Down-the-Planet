# 지형·광물 생성 설계

Godot 4 · `Dig Down the Planet`  
이 문서는 **흙/돌/광석 지형 생성**, **클러스터 규칙**, **오버레이·블록 교체**, **HP(깊이 스케일)**, **스킬 연동**, **청크 경계 처리**를 정리한다.

관련 코드: `scripts/world/WorldGenerator.gd`, `scripts/world/Chunk.gd`, `scripts/world/BlockDef.gd`, `resources/world/block_table.tres`, `resources/tileset/terrain_tileset.tres`  
관련 문서: `MVP_DEVELOPMENT_PLAN.md`, `HUB_CRAFTING_SYSTEM.md`, `SKILL_TREE_DESIGN.md`, `FUEL_SYSTEM_DESIGN.md`

---

## 1. 확정 사항 (요약)

| 항목 | 결정 |
|------|------|
| 기본 지형 | 모든 셀은 **흙(`dirt`)** 으로 채움 |
| 돌 | **블록 교체** — 노이즈 blob 영역의 `block_id`를 `stone`으로 변경 |
| 광석 (초기) | 돌 블록 위 **오버레이** — 별도 스프라이트 레이어, 파괴 시 광물 아이템 추가 드롭 |
| 광맥 (후반 업그레이드) | **돌 blob + 광맥 blob** 둘 다 스폰 (대체 아님) |
| 광맥 블록 (추후) | 업그레이드 해금 후 **블록 교체형 광맥**(`copper_ore` 등) 추가 가능 |
| 흙 광석 (후반 업그레이드) | 흙 셀에도 **희귀 오버레이** 가능 (낮은 확률·깊이 제한) |
| 클러스터 알고리즘 | **방법 A — 2D 노이즈 임계값** (§6) |
| 광석 배치 | 돌 blob **안에서** 고주파 **2차 노이즈**로 서브클러스터(뭉침) |
| 생성 주체 | `WorldGenerator`가 글로벌 좌표 + 런 시드 + **스킬/스탯** 반영 |
| 청크 경계 | **글로벌 좌표 기준 셀 단위 판정** → 청크가 달라도 같은 좌표는 같은 결과 |
| **흙 HP** | `10 + depth_m` (기본 10 + 깊이 m) |
| **돌 HP** | 같은 깊이 흙 HP의 **1.5배** (정수 반올림) |
| **깊이 단위** | `depth_m = global_ty` (타일 1행 = 1m, `TILE_SIZE_PX = 32` — HUD·연료와 동일) |

---

## 2. 게임 루프와의 관계

```
[기본] 전부 흙 → 짧은 런·dirt 스킬 비용·얕은 구간은 쉬운 채굴
[깊이 증가] 흙 HP 상승 (10+m) → 채굴 난이도 자연 상승
[얕은 깊이] 돌 blob 등장 → stone 수집·압착기 루트 (돌은 흙의 1.5배 HP)
[돌 blob 내부] 광석 오버레이 서브클러스터 → 용광로 재료
[스킬 해금] 광맥 blob 추가 스폰 → 고밀도 광물 구간
[추가 스킬] 흙 위 희귀 오버레이 → 후반 런 가치 유지
[추후] 블록 교체형 광맥 → 단단한 고보상 타일
```

경제 연동 (`resources/items/item_database.csv`):

| 자원 | 주 공급 경로 |
|------|----------------|
| `dirt` | 기본 흙 블록 |
| `stone` | 돌 blob(블록 교체) |
| `copper` ~ `gold` | 돌 위 광석 오버레이 → (후반) 광맥 blob·흙 오버레이·광맥 블록 |

---

## 3. 레이어 모델

한 셀은 다음 정보로 표현한다.

| 레이어 | 데이터 | 렌더 | 파괴 시 |
|--------|--------|------|---------|
| **베이스 블록** | `block_id`: `dirt` \| `stone` \| (추후) `copper_ore` … | `TileMapLayer` + `terrain_tileset.tres` | `BlockDef` 드롭 |
| **광석 오버레이** | `ore_overlay_id`: empty \| `copper` \| … | `OreOverlay` (Node2D) | 광물 추가 드롭 |
| **손상 표시** | HP 비율 | `DamageOverlay` | — |

### 3-1. 블록 vs 오버레이 역할

- **돌** = 블록 교체 (`dirt` → `stone`). `stone` 드롭·돌 타일(`tile_rock.png` 등).
- **광석 (초기~중반)** = 돌 블록 위 오버레이. 베이스는 `stone` (HP·돌 드롭 유지).
- **광맥 블록 (추후)** = 블록 교체형 광맥 셀. 전용 HP·드롭·타일.

### 3-2. HP (깊이 스케일) — 확정

HP는 `BlockDef.max_hp` 고정값이 **아니라**, 셀의 **깊이(m)** 로 런타임 계산한다.

#### 깊이

```text
depth_m = float(global_ty)
```

- `global_ty = chunk_index_y * 32 + local_y`
- 지표(y=0) = 0m. HUD `깊이: %.1f m`·`FuelDepthCost`·블록 HP가 **같은 축**을 쓴다.

#### 흙

```text
dirt_hp(depth_m) = DIRT_BASE_HP + depth_m
                 = 10 + depth_m
```

| depth_m | 흙 HP |
|---------|-------|
| 0 | 10 |
| 23 | 33 |
| 100 | 110 |
| 500 | 510 |

#### 돌

같은 깊이에서 흙 HP의 1.5배:

```text
stone_hp(depth_m) = roundi(dirt_hp(depth_m) * 1.5)
```

| depth_m | 흙 HP | 돌 HP |
|---------|-------|-------|
| 0 | 10 | 15 |
| 23 | 33 | 50 |
| 100 | 110 | 165 |
| 500 | 510 | 765 |

#### 구현 메모

- `BlockDef`의 `max_hp`는 **기본값/폴백**으로 두거나, 흙만 `base_hp = 10` 상수로 `WorldGenerator`/`Chunk`에서 계산.
- 청크 스폰 시 `m_cell_hp[cell] = compute_max_hp(block_id, global_ty)`.
- 오버레이는 HP에 **영향 없음** (베이스 블록 HP만 사용).
- (추후) 광맥 블록 HP는 별도 배율·테이블로 확장.

#### 상수 (튜닝용)

| 상수 | 값 | 설명 |
|------|-----|------|
| `DIRT_BASE_HP` | `10` | 깊이 0m 흙 HP |
| `STONE_HP_MULTIPLIER` | `1.5` | 돌 = 흙 × 1.5 |

---

## 4. 클러스터 생성 규칙 (노이즈 A)

### 4-1. 돌 blob (1차 노이즈)

- **알고리즘**: §6 방법 A — 2D 노이즈 임계값.
- **깊이**: `threshold(depth, stats)`를 깊을수록 낮춰 돌 **비중** 증가.
- **범위**: 가로 32타일 전체.
- **결과**: `n > threshold` → `block_id = stone`, 아니면 `dirt`.

### 4-2. 광석 오버레이 서브클러스터 (2차 노이즈)

- `block_id == stone` 인 셀에서만 판정.
- **주파수가 더 높은** 2차 `FastNoiseLite`로 작은 blob 생성.
- 2차 `n_ore > ore_threshold(depth, stats)` → `ore_overlay_id` 설정.
- 광물 종류는 **깊이 테이블** (얕음 구리 → 깊음 은·금).
- 파괴 드롭: `stone` + 광물 (한 번에 셀 제거).

### 4-3. 광맥 blob (스킬 해금 후)

- **돌 blob을 대체하지 않음** — **별도 3차 노이즈 레이어** 또는 별도 threshold로 추가 스폰.
- 광맥 blob 구간: 광석 2차 노이즈의 `ore_threshold`를 낮추거나, 2차 통과 확률·광물 가중을 높임.
- (추후) 블록 교체형 `*_ore` 비율 포함 가능.
- 최소 깊이·스폰 가중은 스킬/스탯으로 제어.

### 4-4. 흙 위 광석 오버레이 (추가 스킬 해금 후)

- `block_id`는 `dirt` 유지. HP는 `10 + depth_m`.
- 희귀하게 `ore_overlay_id`만 부여 (낮은 확률, 깊이 하한).
- 시각: 흙 타일 위 큰 결정 스프라이트 (32px 가독성).

---

## 5. 스킬·스탯 연동 (`WorldGenerator`)

`WorldGenerator`는 런 시드 외에 **스킬/스탯**을 읽어 노이즈 파라미터를 바꾼다.

### 5-1. 읽을 값 (예시)

| 스탯/플래그 | 효과 |
|-------------|------|
| `stone_cluster_density` | 1차 노이즈 `threshold` 감소 → 돌 비중 증가 |
| `vein_cluster_unlock` | 광맥 blob(3차 레이어) 활성 |
| `vein_cluster_density` | 광맥 구간 광석 밀도·threshold |
| `dirt_ore_overlay_unlock` | 흙 셀 광석 오버레이 가능 |
| `dirt_ore_overlay_chance` | 흙 오버레이 확률 (매우 낮게) |

구현: `StatSystem.get_final(&"…")` 또는 스킬 플래그.

### 5-2. 결정론 (재현성)

- 동일 `(global_tx, global_ty)` + 런 시드 + 스킬 스냅샷 → 동일 블록·오버레이.
- 청크 재스폰 시에도 동일.
- 스킬 변경은 **다음 런부터** 반영 (런 중 변경은 MVP 제외 가능).

### 5-3. 플레이어 피드백

- `vein_cluster_unlock`, `dirt_ore_overlay_unlock` 해금 시 UI 한 줄 안내 권장.

---

## 6. 클러스터 알고리즘 — 방법 A (2D 노이즈 임계값)

### 6-1. 원칙

- 청크마다 덩어리를 배치하지 **않음**.
- 타일마다 `evaluate_cell(global_tx, global_ty)` 호출.
- 청크는 좌표 범위만 담당 → **경계 끊김 없음**.

```
글로벌 좌표 (gx, gy)
    → depth_m = gy
    → 1차 noise → block_id (dirt / stone)
    → 2차 noise → ore_overlay_id (stone 셀만)
    → (스킬) 3차 noise → 광맥 blob 보정
    → compute_max_hp(block_id, depth_m)
```

### 6-2. 1차 노이즈 — 돌 blob

```text
n = stone_noise.get_noise_2d(global_tx, global_ty)
if n > threshold(depth_m, stats):
    block_id = stone
else:
    block_id = dirt
```

**파라미터**

| 파라미터 | 역할 |
|----------|------|
| `noise.seed` | `_run_seed` |
| `noise.frequency` | 낮을수록 큰 blob (예: `0.04`) |
| `noise.noise_type` | `TYPE_SIMPLEX_SMOOTH` 권장 |
| `threshold(depth_m)` | 높을수록 돌 적음. 깊이에 따라 `lerp`로 감소 |

**threshold 예시 (튜닝용)**

```text
threshold = lerpf(0.55, 0.05, clampf(depth_m / 200.0, 0.0, 1.0))
threshold -= StatSystem.get_final(&"stone_cluster_density") * 0.01
```

### 6-3. 2차 노이즈 — 광석 서브클러스터

```text
if block_id != stone:
    ore_overlay_id = empty
else:
    n2 = ore_noise.get_noise_2d(global_tx, global_ty)   # frequency 더 높음 (예: 0.12)
    if n2 > ore_threshold(depth_m, stats):
        ore_overlay_id = pick_ore_by_depth(depth_m)
    else:
        ore_overlay_id = empty
```

- 1차 = 큰 돌 덩어리, 2차 = 돌 안의 작은 광석 덩어리.

### 6-4. 3차 — 광맥 blob (스킬 해금 후)

돌 blob과 **독립**으로 밀도만 올리는 방식 예:

```text
if vein_cluster_unlock:
    n3 = vein_noise.get_noise_2d(global_tx, global_ty)
    if n3 > vein_threshold(depth_m, stats):
        # 이 셀이 stone이 아니면 stone으로 승격하거나,
        # 이미 stone이면 ore_threshold를 추가로 낮춤 (광맥 체감)
```

구체 승격 규칙은 구현 시 둘 중 하나로 확정:

- **A안**: 광맥 blob = `stone` 강제 + 2차 threshold 대폭 완화  
- **B안**: 기존 `stone` 셀만 대상으로 2차 통과 확률·희귀 광물 가중 ↑  

### 6-5. 의사코드 (Godot)

```gdscript
static func evaluate_cell(global_tx: int, global_ty: int) -> Dictionary:
    var depth_m := float(global_ty)
    var block_id := &"dirt"
    var n := _stone_noise.get_noise_2d(float(global_tx), float(global_ty))
    if n > _stone_threshold(depth_m):
        block_id = &"stone"

    var ore_overlay_id := &""
    if block_id == &"stone":
        var n2 := _ore_noise.get_noise_2d(float(global_tx), float(global_ty))
        if n2 > _ore_threshold(depth_m):
            ore_overlay_id = _pick_ore_by_depth(depth_m)

    if _vein_unlocked():
        _apply_vein_blob_bonus(global_tx, global_ty, depth_m, block_id, ore_overlay_id)

    var max_hp := compute_max_hp(block_id, depth_m)
    return { "block_id": block_id, "ore_overlay_id": ore_overlay_id, "max_hp": max_hp }


static func compute_max_hp(block_id: StringName, depth_m: float) -> int:
    var dirt_hp := int(DIRT_BASE_HP) + int(depth_m)
    if block_id == &"stone":
        return roundi(float(dirt_hp) * STONE_HP_MULTIPLIER)
    return dirt_hp
```

### 6-6. 청크 경계

같은 `(gx, gy)`는 어느 청크에서 채우든 동일 결과 → blob이 경계에서 이어짐.  
**청크 로컬 전용 배치는 사용하지 않음.**

---

## 7. 깊이·광물 분포 (튜닝 초안)

| 깊이 구간 (예) | 돌 blob (1차) | 광석 (2차, stone 내부) | 흙 HP (참고) |
|----------------|---------------|------------------------|--------------|
| 0 ~ 20m | threshold 높음 → 돌 적음 | 구리만, 희귀 | 10 ~ 30 |
| 20 ~ 80m | threshold 중간 | 구리·철 | 30 ~ 90 |
| 80m+ | threshold 낮음 → 돌 많음 | 철·은·금 | 90+ |

**광맥 blob** (스킬): 40m+ 등 최소 깊이 권장.  
**흙 오버레이** (스킬): 전 구간 가능, 확률 극低.

---

## 8. 데이터·코드 변경 방향 (구현 시 참고)

### 8-1. `BlockDef` / `block_table.tres`

- `stone` 행 추가 (`drop_item_id = stone`). `max_hp`는 깊이 공식 사용 시 **미사용 또는 폴백**.
- `DIRT_BASE_HP = 10`은 코드 상수 또는 `BlockDef` 흙 행 참조.

### 8-2. `WorldGenerator.gd`

- `evaluate_cell(global_tx, global_ty)` — 블록·오버레이·`max_hp` 반환.
- `compute_max_hp(block_id, depth_m)`.
- `FastNoiseLite` 1~3개 (stone / ore / vein).
- `atlas_for_cell` (흙·돌 시각 변형) 유지.

### 8-3. `Chunk.gd`

- `_fill_tiles()`: `evaluate_cell` → `set_cell`, `m_cell_hp`, 오버레이.
- 스폰 시 `block_id`·`global_ty` 셀별 저장 (HP 재계산 시 깊이 참조).
- `block_id_for_cell` → 저장값 사용.

### 8-4. 씬 / 렌더

- `OreOverlay` 노드 추가.
- `terrain_tileset.tres`: `tile_rock.png` 소스 추가.

### 8-5. 스킬 데이터

- `StatSystem` 스탯 id와 `WorldGenerator` 조회 키 **동일 이름** 유지.

---

## 9. 파괴·드롭 규칙

| 셀 상태 | 드롭 |
|---------|------|
| `dirt` | `dirt` ×1 |
| `stone` | `stone` ×1 |
| `stone` + 광석 오버레이 | `stone` ×1 + 광물 ×1 |
| `dirt` + 광석 오버레이 | `dirt` ×1 + 광물 ×1 |
| (추후) `copper_ore` 블록 | `copper` ×N |

HP: §3-2 공식. 오버레이는 HP에 영향 없음.

---

## 10. 구현 단계 제안

| 단계 | 내용 |
|------|------|
| 1 | `evaluate_cell` + 1차 노이즈 돌 blob + `stone` 타일 + **깊이 HP** |
| 2 | `OreOverlay` + 2차 노이즈 광석 + 드롭 |
| 3 | 깊이 테이블·광물 종류 가중 |
| 4 | 스킬: 광맥 blob (3차) |
| 5 | 스킬: 흙 오버레이 |
| 6 | (추후) 블록 교체형 광맥 + 전용 타일·HP |

---

## 11. 열린 결정 (구현 전 확정 권장)

- [x] 클러스터 알고리즘: **방법 A (2D 노이즈 임계값)**
- [x] 흙 HP: `10 + depth_m`
- [x] 돌 HP: 흙 HP × `1.5` (`roundi`)
- [ ] 광석 오버레이 시 `stone` 드롭 항상 유지 vs 광물만 (현재안: `stone` + 광물)
- [ ] 광맥 blob 3차: stone 강제 승격 vs 기존 stone 밀도만 상향 (§6-4 A안/B안)
- [ ] 1차·2차 `frequency` / `threshold` 초기값 (플레이테스트)
- [ ] 광맥·흙 오버레이 최소 해금 깊이
- [ ] (추후) 블록 교체형 광맥 HP 배율

---

## 12. 한 줄 요약

**전부 흙으로 시작하고, 글로벌 좌표 2D 노이즈(방법 A)로 돌·광맥 blob을 깊이·스킬에 따라 깐다. 돌은 블록 교체, 광석은 돌 위 2차 노이즈 오버레이, HP는 흙 `10+깊이(m)`·돌 `×1.5`. 청크는 좌표만 나누고 `WorldGenerator.evaluate_cell`이 셀마다 동일 규칙을 적용한다.**

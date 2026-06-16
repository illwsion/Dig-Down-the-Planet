class_name WorldGenerator
extends RefCounted

## 글로벌 타일 좌표 (global_tx, global_ty)에 대해 블록 종류·타일·HP를 결정한다.
## Chunk는 로컬 x와 chunk_index_y로 global_ty를 만들어 넘긴다.
## _run_seed: 게임 실행마다 바꾸면 같은 좌표도 패턴이 달라진다(한 판 안에서는 동일 유지).

const SOURCE_ID_DIRT := 0
const SOURCE_ID_STONE := 1

const DIRT_BASE_HP := 6
const STONE_HP_MULTIPLIER := 1.5

## 돌 blob의 공간 스케일. 값이 클수록 더 자잘한 돌 무늬, 작을수록 큰 덩어리가 된다.
const STONE_NOISE_FREQUENCY := 0.04
## 얕은 깊이에서 돌로 판정되기 위한 노이즈 기준값. 낮을수록 얕은 곳에도 돌이 많아진다.
const STONE_THRESHOLD_SHALLOW := 0.25
## 깊은 곳에서 돌로 판정되기 위한 노이즈 기준값. 낮을수록 깊은 곳의 돌 비율이 높아진다.
const STONE_THRESHOLD_DEEP := 0.05
## 얕은 기준값에서 깊은 기준값으로 서서히 바뀌는 거리. 값이 클수록 돌 증가가 완만해진다.
const STONE_DEPTH_RAMP_M := 200.0
## 스킬 `stone_cluster_density` 1당 threshold에서 빼는 양 (돌 비중 증가).
const STONE_CLUSTER_DENSITY_THRESHOLD_SCALE := 0.01

## 광물이 "있는 위치"를 정하는 노이즈 스케일. 값이 클수록 작은 광석 덩어리, 작을수록 큰 광맥이 된다.
const ORE_MASK_NOISE_FREQUENCY := 0.12
## 광물 생성 기준값. 낮을수록 광물 등장량이 늘고, 높을수록 더 희귀해진다.
const ORE_MASK_THRESHOLD := 0.3
## 광물 "종류"를 정하는 노이즈 스케일. 값이 작을수록 주변 셀끼리 같은 광물 종류가 이어진다.
const ORE_TYPE_NOISE_FREQUENCY := 0.025
## 철로 판정되는 기준값. 낮을수록 철 비율이 늘고, 높을수록 구리 비율이 늘어난다.
const ORE_TYPE_IRON_THRESHOLD := 0.15

static var _run_seed: int = 0
static var _stone_noise: FastNoiseLite
static var _ore_mask_noise: FastNoiseLite
static var _ore_type_noise: FastNoiseLite


static func randomize_run_seed() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	_run_seed = r.randi()
	_sync_stone_noise_seed()
	_sync_ore_noise_seeds()


static func evaluate_cell(global_tx: int, global_ty: int) -> Dictionary:
	var depth_m := float(global_ty)
	var block_id := &"dirt"
	if is_stone_block(global_tx, global_ty):
		block_id = &"stone"

	var source_id := SOURCE_ID_DIRT if block_id == &"dirt" else SOURCE_ID_STONE
	return {
		"block_id": block_id,
		"source_id": source_id,
		"atlas": atlas_for_cell(global_tx, global_ty),
		"max_hp": compute_max_hp(block_id, depth_m),
		"ore_overlay_id": ore_overlay_for_cell(block_id, global_tx, global_ty),
	}


static func is_stone_block(global_tx: int, global_ty: int) -> bool:
	_ensure_stone_noise()
	var n := _stone_noise.get_noise_2d(float(global_tx), float(global_ty))
	return n > _stone_threshold(float(global_ty))


static func compute_max_hp(block_id: StringName, depth_m: float) -> int:
	var dirt_hp := DIRT_BASE_HP + int(depth_m)
	if block_id == &"stone":
		return roundi(float(dirt_hp) * STONE_HP_MULTIPLIER)
	return dirt_hp


static func ore_overlay_for_cell(block_id: StringName, global_tx: int, global_ty: int) -> StringName:
	if block_id != &"stone":
		return &""
	_ensure_ore_noises()
	var mask := _ore_mask_noise.get_noise_2d(float(global_tx), float(global_ty))
	if mask <= ORE_MASK_THRESHOLD:
		return &""
	var ore_type := _ore_type_noise.get_noise_2d(float(global_tx), float(global_ty))
	if ore_type > ORE_TYPE_IRON_THRESHOLD:
		return &"iron"
	return &"copper"


static func atlas_for_cell(global_tx: int, global_ty: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_tx, global_ty)) ^ _run_seed
	return Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))


static func _stone_threshold(depth_m: float) -> float:
	var t := clampf(depth_m / STONE_DEPTH_RAMP_M, 0.0, 1.0)
	var threshold := lerpf(STONE_THRESHOLD_SHALLOW, STONE_THRESHOLD_DEEP, t)
	threshold -= StatSystem.get_final(&"stone_cluster_density") * STONE_CLUSTER_DENSITY_THRESHOLD_SCALE
	return threshold


static func _ensure_stone_noise() -> void:
	if _stone_noise != null:
		return
	_stone_noise = FastNoiseLite.new()
	_stone_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_stone_noise.frequency = STONE_NOISE_FREQUENCY
	_stone_noise.seed = _run_seed


static func _ensure_ore_noises() -> void:
	if _ore_mask_noise == null:
		_ore_mask_noise = FastNoiseLite.new()
		_ore_mask_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ore_mask_noise.frequency = ORE_MASK_NOISE_FREQUENCY
		_ore_mask_noise.seed = _run_seed ^ 0x4F52454D
	if _ore_type_noise == null:
		_ore_type_noise = FastNoiseLite.new()
		_ore_type_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ore_type_noise.frequency = ORE_TYPE_NOISE_FREQUENCY
		_ore_type_noise.seed = _run_seed ^ 0x4F524554


static func _sync_stone_noise_seed() -> void:
	_ensure_stone_noise()
	if _stone_noise != null:
		_stone_noise.seed = _run_seed


static func _sync_ore_noise_seeds() -> void:
	_ensure_ore_noises()
	if _ore_mask_noise != null:
		_ore_mask_noise.seed = _run_seed ^ 0x4F52454D
	if _ore_type_noise != null:
		_ore_type_noise.seed = _run_seed ^ 0x4F524554

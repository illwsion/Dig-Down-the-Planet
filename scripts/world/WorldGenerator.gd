class_name WorldGenerator
extends RefCounted

## 글로벌 타일 좌표 (global_tx, global_ty)에 대해 블록 종류·타일·HP를 결정한다.
## Chunk는 로컬 x와 chunk_index_y로 global_ty를 만들어 넘긴다.
## _run_seed: 게임 실행마다 바꾸면 같은 좌표도 패턴이 달라진다(한 판 안에서는 동일 유지).

const SOURCE_ID_DIRT := 0
const SOURCE_ID_STONE := 1

const DIRT_BASE_HP := 6
const STONE_HP_MULTIPLIER := 1.5

const STONE_NOISE_FREQUENCY := 0.04
const STONE_THRESHOLD_SHALLOW := 0.55
const STONE_THRESHOLD_DEEP := 0.05
const STONE_DEPTH_RAMP_M := 200.0
## 스킬 `stone_cluster_density` 1당 threshold에서 빼는 양 (돌 비중 증가).
const STONE_CLUSTER_DENSITY_THRESHOLD_SCALE := 0.01

static var _run_seed: int = 0
static var _stone_noise: FastNoiseLite


static func randomize_run_seed() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	_run_seed = r.randi()
	_sync_stone_noise_seed()


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
		"ore_overlay_id": &"",
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


static func _sync_stone_noise_seed() -> void:
	_ensure_stone_noise()
	if _stone_noise != null:
		_stone_noise.seed = _run_seed

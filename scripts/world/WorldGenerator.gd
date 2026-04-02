class_name WorldGenerator
extends RefCounted

## 글로벌 타일 좌표 (global_tx, global_ty)에 대해 TileSet 아틀라스 좌표를 결정한다.
## Chunk는 로컬 x와 chunk_index_y로 global_ty를 만들어 넘긴다.
## _run_seed: 게임 실행마다 바꾸면 같은 좌표도 패턴이 달라진다(한 판 안에서는 동일 유지).

static var _run_seed: int = 0


static func randomize_run_seed() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	_run_seed = r.randi()


static func atlas_for_cell(global_tx: int, global_ty: int) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_tx, global_ty)) ^ _run_seed
	return Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))

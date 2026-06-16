class_name SkillIcons

## icon_skill.png (128×128, 32×32 그리드 4×4)에서 icon_id별 아이콘 region을 반환한다.

const c_Atlas := preload("res://assets/sprites/icon_skill.png")
const c_CellSize := 32
const c_GridCols := 4

## icon_id → 시트 칸 index (왼쪽→오른쪽, 위→아래). 여러 스킬이 같은 icon_id를 쓸 수 있다.
const c_IconIndex: Dictionary = {
	&"drill":            0,
	&"drill_move":       1,
	&"drill_power":      2,
	&"inventory_add":    3,
	&"inventory_stack":  4,
	&"fuel_cost":        5,
	&"fuel_max":         6,
	&"drill_accel":      7,
	&"drill_turn":       8,
}

static var _cache: Dictionary = {}


static func get_icon(_icon_id: StringName) -> Texture2D:
	if _icon_id == &"" or not c_IconIndex.has(_icon_id):
		return null
	if _cache.has(_icon_id):
		return _cache[_icon_id]

	var index: int = c_IconIndex[_icon_id]
	var col: int = index % c_GridCols
	var row: int = index / c_GridCols
	var tex := AtlasTexture.new()
	tex.atlas = c_Atlas
	tex.region = Rect2(col * c_CellSize, row * c_CellSize, c_CellSize, c_CellSize)
	_cache[_icon_id] = tex
	return tex

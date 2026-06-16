class_name ItemIcons

## item.png (128×128, 32×32 그리드 4×4)에서 아이템 id별 아이콘 region을 반환한다.

const c_Atlas := preload("res://assets/sprites/item.png")
const c_CellSize := 32
const c_GridCols := 4

## item_id → 시트 칸 index (왼쪽→오른쪽, 위→아래).
const c_IconIndex: Dictionary = {
	&"dirt":         0,
	&"dirt_brick":   1,
	&"stone":        2,
	&"stone_brick":  3,
	&"copper_ore":   4,
	&"copper_ingot": 5,
	&"iron_ore":     6,
	&"iron_ingot":   7,
}

static var _cache: Dictionary = {}


static func get_icon(_item_id: StringName) -> Texture2D:
	if not c_IconIndex.has(_item_id):
		return null
	if _cache.has(_item_id):
		return _cache[_item_id]

	var index: int = c_IconIndex[_item_id]
	var col: int = index % c_GridCols
	var row: int = index / c_GridCols
	var tex := AtlasTexture.new()
	tex.atlas = c_Atlas
	tex.region = Rect2(col * c_CellSize, row * c_CellSize, c_CellSize, c_CellSize)
	_cache[_item_id] = tex
	return tex

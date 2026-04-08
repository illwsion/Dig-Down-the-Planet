extends Node

## 아이템 데이터베이스. Autoload로 등록해 전역에서 사용한다.
## 시작 시 item_database.csv를 파싱해 캐시하며, ItemDatabase.get_def(id)로 조회한다.
##
## CSV 컬럼 순서 (0-based):
##  0  id
##  1  display_name
##  2  sell_price
##  3  category   ("raw" | "processed")
##
## 새 아이템 추가: item_database.csv에 행 하나만 추가하면 된다.

const c_CsvPath := "res://resources/items/item_database.csv"

## { item_id: StringName -> ItemDef }
var _defs: Dictionary = {}


func _ready() -> void:
	_load_csv()


## id로 ItemDef를 반환한다. 없으면 null.
func get_def(_id: StringName) -> ItemDef:
	if _defs.has(_id):
		return _defs[_id]
	push_warning("ItemDatabase: 알 수 없는 item_id '%s'" % _id)
	return null


func _load_csv() -> void:
	var file := FileAccess.open(c_CsvPath, FileAccess.READ)
	if file == null:
		push_error("ItemDatabase: CSV를 찾을 수 없음 — " + c_CsvPath)
		return

	file.get_csv_line()  # 헤더 스킵 (UTF-8 BOM이 있어도 이 행에서 함께 소비됨)

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 4 or row[0].strip_edges().is_empty():
			continue
		var def := ItemDef.new()
		def.id           = StringName(row[0].strip_edges())
		def.display_name = row[1].strip_edges()
		def.sell_price   = int(row[2].strip_edges())
		def.category     = StringName(row[3].strip_edges())
		_defs[def.id]    = def

	print("ItemDatabase: %d개 아이템 로드 완료" % _defs.size())

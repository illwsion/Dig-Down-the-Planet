class_name BlockTable
extends Resource

## 여러 [BlockDef]를 묶어 인스펙터·.tres에서 편집한다.

@export var blocks: Array[BlockDef] = []


func get_max_hp(block_id: StringName) -> int:
	for b in blocks:
		if b != null and b.id == block_id:
			return b.max_hp
	push_warning("BlockTable: unknown block_id %s, using 1" % block_id)
	return 1


func get_def(block_id: StringName) -> BlockDef:
	for b in blocks:
		if b != null and b.id == block_id:
			return b
	push_warning("BlockTable: unknown block_id %s" % block_id)
	return null

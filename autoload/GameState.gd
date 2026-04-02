extends Node

## 전역 게임 상태 (자원, 골드, 인벤 참조 등).

func _ready() -> void:
	# Autoload는 메인 씬·자식 노드보다 먼저 _ready됨. World가 청크를 채우기 전에 실행해야 함.
	WorldGenerator.randomize_run_seed()

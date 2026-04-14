extends Node

## 게임 전체의 루트. Hub는 항상 자식으로 유지하고, Main은 런 시작 시 생성·귀환 시 제거한다.
## 씬 전환은 get_tree().change_scene_to_file() 대신 enter_run() / return_to_hub()를 사용한다.

const c_MainScene := preload("res://scenes/main/Main.tscn")

@onready var m_hub: Node2D = $Hub

## 현재 활성화된 Main 인스턴스. 런 중이 아니면 null.
var m_run: Node2D = null


func _ready() -> void:
	add_to_group("game_root")


## Hub → 채굴: GameState 초기화 → Hub 숨김 → Main 새로 생성 후 트리에 추가.
func enter_run() -> void:
	if m_run != null:
		push_warning("GameRoot.enter_run: 이미 런이 진행 중입니다.")
		return

	GameState.start_run()

	m_hub.set_hub_visible(false)
	m_hub.process_mode = Node.PROCESS_MODE_DISABLED

	m_run = c_MainScene.instantiate()
	add_child(m_run)


## 채굴 → Hub: 귀환 처리 → Main 제거 → Hub 다시 활성화.
func return_to_hub() -> void:
	for drop in get_tree().get_nodes_in_group("drop_items"):
		drop.queue_free()
	GameState.transfer_run_to_hub()

	if m_run != null:
		m_run.queue_free()
		m_run = null

	m_hub.set_hub_visible(true)
	m_hub.process_mode = Node.PROCESS_MODE_INHERIT
	m_hub.update_dollars_label()

extends Node2D

const c_FlyDurationSec: float = 0.45
const c_FlyIconSize: Vector2 = Vector2(32, 32)

@onready var m_ui_layer: CanvasLayer = $UILayer
@onready var m_fly_layer: Control = $UILayer/FlyLayer
@onready var m_start_button: Button = $UILayer/StartButton
@onready var m_skill_tree_button: Button = $UILayer/SkillTreeButton
@onready var m_skill_tree_panel: PanelContainer = $UILayer/SkillTreePanel
@onready var m_close_button: Button = $UILayer/SkillTreePanel/VBox/HeaderBar/CloseButton
@onready var m_skill_tree_view = $UILayer/SkillTreePanel/VBox/SkillTreeView
@onready var m_dollars_label: Label = $UILayer/DollarsLabel
@onready var m_inventory_panel = $UILayer/HubInventoryPanel


func _ready() -> void:
	add_to_group("hub")
	m_start_button.pressed.connect(_on_start_button_pressed)
	m_skill_tree_button.pressed.connect(_on_skill_tree_button_pressed)
	m_close_button.pressed.connect(_on_close_button_pressed)
	m_inventory_panel.dollars_changed.connect(update_dollars_label)
	GameState.dollars_changed.connect(update_dollars_label)
	m_inventory_panel.refresh()
	update_dollars_label()


## Hub 전체(월드 + UI 레이어)를 보이거나 숨긴다.
## CanvasLayer는 부모 visible을 상속하지 않으므로 별도 처리가 필요하다.
func set_hub_visible(_value: bool) -> void:
	visible = _value
	m_ui_layer.visible = _value


## 달러 레이블 갱신. HubInventoryPanel 판매 후, 귀환 직후 등에서 호출한다.
func update_dollars_label() -> void:
	m_dollars_label.text = "$ %d" % GameState.dollars


## 자원 비행 연출 시작점(글로벌). MachineNode 등에서 호출한다.
func get_fly_start_global_position() -> Vector2:
	return m_inventory_panel.get_fly_start_global_position()


## 아이템 아이콘을 글로벌 좌표 간으로 비행시킨다. 완료 시 `_on_finished` 호출 후 비행 노드는 제거된다.
func play_item_fly(_texture: Texture2D, _from_global: Vector2, _to_global: Vector2, _on_finished: Callable) -> void:
	if m_fly_layer == null:
		if _on_finished.is_valid():
			_on_finished.call()
		return
	if _texture == null:
		push_warning("Hub.play_item_fly: texture가 null입니다.")
		if _on_finished.is_valid():
			_on_finished.call()
		return

	var fly: TextureRect = TextureRect.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.texture = _texture
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.custom_minimum_size = c_FlyIconSize
	fly.size = c_FlyIconSize
	m_fly_layer.add_child(fly)

	# Control에는 to_local이 없을 수 있어 CanvasItem 글로벌 변환 역행렬로 변환한다.
	var inv: Transform2D = m_fly_layer.get_global_transform().affine_inverse()
	var start_local: Vector2 = inv * _from_global
	var end_local: Vector2 = inv * _to_global
	fly.position = start_local - c_FlyIconSize * 0.5
	end_local -= c_FlyIconSize * 0.5

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fly, "position", end_local, c_FlyDurationSec)
	tween.finished.connect(_on_fly_fx_finished.bind(fly, _on_finished))


func _on_fly_fx_finished(_fly: TextureRect, _callback: Callable) -> void:
	if _callback.is_valid():
		_callback.call()
	if is_instance_valid(_fly):
		_fly.queue_free()


func _on_start_button_pressed() -> void:
	var game_root: Node = get_tree().get_first_node_in_group("game_root")
	if game_root != null:
		game_root.enter_run()
	else:
		push_error("Hub: game_root 그룹에 GameRoot가 없습니다.")


func _on_skill_tree_button_pressed() -> void:
	m_skill_tree_panel.visible = true
	# visible = true 이후 레이아웃 계산이 끝난 다음 프레임에 refresh 호출
	m_skill_tree_view.call_deferred("refresh", true)


func _on_close_button_pressed() -> void:
	m_skill_tree_panel.visible = false

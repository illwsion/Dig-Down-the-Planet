class_name MachineNode
extends Node2D

## 기계 공통 노드. MachineDef 리소스를 연결해 압착기·용광로 등에 재사용한다.

#region Enums
enum MachineState {
	IDLE,     # 대기 중
	LOADING,  # 자원 투입 중 (초기엔 즉시 전환, C-3 이후 Tween 연출용으로 예약)
	FULL,     # input_count 도달 — 레버 대기, 자동 레버 업그레이드 발동 대상
	PARTIAL,  # 1개 이상 투입됐으나 input_count 미달 — 레버는 비활성(FULL만 작동)
	RUNNING,  # 가공 중 (게이지 감소)
	DONE,     # 가공 완료 — collect_output() 자동 호출 후 IDLE 복귀
}
#endregion

#region Signals
## 가공 완료 후 산출물을 hub_inventory에 넣었을 때 emit.
signal output_collected
#endregion

#region Private Fields
@export var m_def: MachineDef

@onready var m_gauge_bar: ProgressBar = $GaugeBar
@onready var m_lever_button: Button = $LeverButton
@onready var m_name_label: Label = $NameLabel
@onready var m_click_area: Area2D = $ClickArea
@onready var m_sprite: Sprite2D = $Sprite2D

var m_state: MachineState = MachineState.IDLE

## 게이지 비율 (0.0 ~ 1.0). 비행 아이콘이 도착할 때만 갱신한다.
var m_gauge: float = 0.0

## 클릭 즉시 반영되는 예약 적재량. `input_count` 초과 클릭을 막는다.
var m_loaded_count: int = 0

## 비행 Tween이 끝난 횟수. 게이지·FULL 판정은 이 값 기준이다.
var m_arrived_count: int = 0

## 현재 사이클에서 선택된 레시피. IDLE 복귀 시 null로 초기화된다.
var m_chosen_recipe: MachineRecipe = null

var m_run_timer: float = 0.0

## RUNNING 진입 시점의 게이지 값. 부분 투입 후 가공 시 여기서부터 감소한다.
var m_run_start_gauge: float = 1.0

## Hub 씬 루트 (`Hub.gd`, 그룹 `hub`). `play_item_fly` 등 연출은 여기로 위임한다.
var m_hub: Node = null
#endregion

#region Unity Lifecycle
func _ready() -> void:
	m_lever_button.pressed.connect(_on_lever_button_pressed)
	m_click_area.input_event.connect(_on_click_area_input_event)
	_resolve_hub_ref()
	_update_ui()

	if m_def != null:
		m_name_label.text = m_def.display_name


func _process(_delta: float) -> void:
	if m_state == MachineState.RUNNING:
		m_run_timer += _delta
		var t: float = clampf(m_run_timer / m_def.process_time, 0.0, 1.0)
		m_gauge = m_run_start_gauge * (1.0 - t)
		_update_gauge_bar()

		if m_run_timer >= m_def.process_time:
			_set_state(MachineState.DONE)
#endregion

#region Public Methods
## ClickArea 클릭 시 호출. 클릭 1번에 창고 즉시 차감·내부 예약 증가, 게이지는 비행 완료 후 갱신.
## IDLE: 가장 비싼 산출품 레시피 선택. PARTIAL: 선택된 레시피 유지.
func try_load_from_hub() -> void:
	if m_def == null:
		return
	if m_state == MachineState.RUNNING or m_state == MachineState.DONE:
		return
	if m_state == MachineState.FULL or m_state == MachineState.LOADING:
		return
	if m_state != MachineState.IDLE and m_state != MachineState.PARTIAL:
		return
	if m_loaded_count >= m_def.input_count:
		return

	# 레시피 결정
	if m_state == MachineState.IDLE:
		var sorted_recipes := m_def.recipes.duplicate()
		sorted_recipes.sort_custom(func(a: MachineRecipe, b: MachineRecipe) -> bool:
			return _get_sell_price(a.output_id) > _get_sell_price(b.output_id)
		)
		for recipe: MachineRecipe in sorted_recipes:
			if GameState.hub_inventory.get_count(recipe.input_id) > 0:
				m_chosen_recipe = recipe
				break
		if m_chosen_recipe == null:
			return
	else:
		if GameState.hub_inventory.get_count(m_chosen_recipe.input_id) <= 0:
			return

	GameState.hub_inventory.remove_item(m_chosen_recipe.input_id, 1)
	m_loaded_count += 1

	_ensure_hub_ref()

	var item_def: ItemDef = ItemDatabase.get_def(m_chosen_recipe.input_id)
	var tex: Texture2D = item_def.icon if item_def != null else null
	var from_global: Vector2 = Vector2.ZERO
	var to_global: Vector2 = m_sprite.global_position
	if is_instance_valid(m_hub):
		var fg: Variant = m_hub.call(&"get_fly_start_global_position")
		if fg is Vector2:
			from_global = fg

	if is_instance_valid(m_hub):
		m_hub.call(&"play_item_fly", tex, from_global, to_global, Callable(self, "_on_inventory_fly_finished"))
	else:
		push_warning("MachineNode: Hub를 찾을 수 없어 비행 없이 즉시 도착 처리합니다.")
		call_deferred("_on_inventory_fly_finished")

	_refresh_state_after_commit()


## 레버 클릭 시 호출. FULL 상태일 때만 RUNNING으로 전환.
func start_processing() -> void:
	if m_state != MachineState.FULL:
		return
	m_run_timer = 0.0
	m_run_start_gauge = m_gauge
	_set_state(MachineState.RUNNING)


## DONE 전환 시 자동 호출. m_chosen_recipe와 m_def.output_count 기반으로 산출 후 hub_inventory에 추가.
func collect_output() -> void:
	if m_chosen_recipe == null:
		return
	GameState.hub_inventory.add_item(m_chosen_recipe.output_id, m_def.output_count)
	emit_signal("output_collected")
	m_loaded_count = 0
	m_arrived_count = 0
	m_chosen_recipe = null
	m_gauge = 0.0
	_set_state(MachineState.IDLE)
#endregion

#region Private Methods
func _ensure_hub_ref() -> void:
	if is_instance_valid(m_hub):
		return
	_resolve_hub_ref()


func _resolve_hub_ref() -> void:
	m_hub = get_tree().get_first_node_in_group("hub")
	if m_hub != null:
		return
	var n: Node = get_parent()
	while n != null:
		if n.name == &"Hub":
			m_hub = n
			return
		n = n.get_parent()
	push_warning("MachineNode: Hub를 찾지 못했습니다. 그룹 'hub' 또는 이름이 Hub인 조상 노드가 필요합니다.")


## 창고 차감·내부 예약 직후. 게이지·FULL은 비행 완료 콜백에서만 맞춘다.
func _refresh_state_after_commit() -> void:
	if m_loaded_count >= m_def.input_count and m_arrived_count < m_def.input_count:
		_set_state(MachineState.LOADING)
	else:
		_set_state(MachineState.PARTIAL)


## 비행 Tween 종료 1회마다 호출. `m_gauge`·FULL·자동 레버는 여기서만 반영한다.
func _on_inventory_fly_finished() -> void:
	if m_def == null:
		return
	m_arrived_count += 1
	m_gauge = clampf(float(m_arrived_count) / float(m_def.input_count), 0.0, 1.0)
	_update_gauge_bar()

	if m_arrived_count >= m_def.input_count:
		_set_state(MachineState.FULL)
		if GameState.get("auto_lever") == true:
			start_processing()
	elif m_loaded_count >= m_def.input_count:
		_set_state(MachineState.LOADING)
	else:
		_set_state(MachineState.PARTIAL)


func _set_state(_next: MachineState) -> void:
	m_state = _next
	_update_ui()

	if m_state == MachineState.DONE:
		collect_output()


func _update_ui() -> void:
	_update_gauge_bar()
	_update_lever_button()


func _update_gauge_bar() -> void:
	m_gauge_bar.value = m_gauge * 100.0


func _update_lever_button() -> void:
	m_lever_button.disabled = m_state != MachineState.FULL


func _on_lever_button_pressed() -> void:
	start_processing()


func _on_click_area_input_event(_viewport: Node, _event: InputEvent, _shape_idx: int) -> void:
	if _event is InputEventMouseButton and _event.pressed and _event.button_index == MOUSE_BUTTON_LEFT:
		try_load_from_hub()


func _get_sell_price(_item_id: StringName) -> int:
	var def: ItemDef = ItemDatabase.get_def(_item_id)
	if def == null:
		return 0
	return def.sell_price
#endregion

class_name MachineNode
extends Node2D

## 기계 공통 노드. MachineDef 리소스를 연결해 압착기·용광로 등에 재사용한다.

#region Enums
enum MachineState {
	IDLE,     # 대기 중
	LOADING,  # 자원 투입 중 (초기엔 즉시 전환, C-3 이후 Tween 연출용으로 예약)
	FULL,     # input_count 도달 — 레버 대기, 자동 레버 업그레이드 발동 대상
	PARTIAL,  # 1개 이상 투입됐으나 input_count 미달 — 레버 클릭 가능, 자동 레버 발동 안 함
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

var m_state: MachineState = MachineState.IDLE

## 게이지 비율 (0.0 ~ 1.0).
var m_gauge: float = 0.0

## 현재 투입된 아이템 수.
var m_loaded_count: int = 0

## 현재 사이클에서 선택된 레시피. IDLE 복귀 시 null로 초기화된다.
var m_chosen_recipe: MachineRecipe = null

var m_run_timer: float = 0.0
#endregion

#region Unity Lifecycle
func _ready() -> void:
	m_lever_button.pressed.connect(_on_lever_button_pressed)
	m_click_area.input_event.connect(_on_click_area_input_event)
	_update_ui()

	if m_def != null:
		m_name_label.text = m_def.display_name


func _process(_delta: float) -> void:
	if m_state == MachineState.RUNNING:
		m_run_timer += _delta
		m_gauge = 1.0 - clampf(m_run_timer / m_def.process_time, 0.0, 1.0)
		_update_gauge_bar()

		if m_run_timer >= m_def.process_time:
			_set_state(MachineState.DONE)
#endregion

#region Public Methods
## ClickArea 클릭 시 호출. 클릭 1번에 아이템 1개 투입.
## IDLE: 가장 비싼 산출품 레시피 선택. PARTIAL: 선택된 레시피 유지.
func try_load_from_hub() -> void:
	if m_def == null:
		return
	if m_state != MachineState.IDLE and m_state != MachineState.PARTIAL:
		return
	if m_loaded_count >= m_def.input_count:
		return

	# 레시피 결정
	if m_state == MachineState.IDLE:
		# 산출품 판매가 기준 내림차순으로 재료가 있는 첫 번째 레시피 선택
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
		# PARTIAL: 이미 선택된 레시피의 재료가 떨어졌으면 투입 불가
		if GameState.hub_inventory.get_count(m_chosen_recipe.input_id) <= 0:
			return

	# 창고에서 1개 차감
	GameState.hub_inventory.remove_item(m_chosen_recipe.input_id, 1)
	m_loaded_count += 1

	m_gauge = clampf(float(m_loaded_count) / float(m_def.input_count), 0.0, 1.0)

	if m_loaded_count >= m_def.input_count:
		_set_state(MachineState.FULL)
		# 자동 레버 업그레이드 (Phase F-2 대비 — FULL 상태일 때만 발동)
		if GameState.get("auto_lever") == true:
			start_processing()
	else:
		_set_state(MachineState.PARTIAL)


## 레버 클릭 시 호출. FULL 또는 PARTIAL 상태일 때 RUNNING으로 전환.
func start_processing() -> void:
	if m_state != MachineState.FULL and m_state != MachineState.PARTIAL:
		return
	m_run_timer = 0.0
	_set_state(MachineState.RUNNING)


## DONE 전환 시 자동 호출. m_chosen_recipe와 m_def.output_count 기반으로 산출 후 hub_inventory에 추가.
func collect_output() -> void:
	if m_chosen_recipe == null:
		return
	GameState.hub_inventory.add_item(m_chosen_recipe.output_id, m_def.output_count)
	emit_signal("output_collected")
	m_loaded_count = 0
	m_chosen_recipe = null
	m_gauge = 0.0
	_set_state(MachineState.IDLE)
#endregion

#region Private Methods
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
	var can_start := m_state == MachineState.FULL or m_state == MachineState.PARTIAL
	m_lever_button.disabled = not can_start


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

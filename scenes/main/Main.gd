extends Node2D

## 이동/조준은 Drill에서 처리: 마우스 왼쪽 홀드 시 전진 + 마우스 방향으로 천천히 회전(±30°). Main은 HUD·슬라이더.

signal run_end_requested(reason: StringName)

const END_REASON_FUEL_DEPLETED: StringName = &"fuel_depleted"
const END_REASON_RETURN_TO_HUB: StringName = &"return_to_hub"
const TILE_SIZE_PX := 32
const DEFAULT_MOVE_SPEED_PX := 400.0

var m_move_speed_px: float = DEFAULT_MOVE_SPEED_PX
var m_max_depth_m: float = 0.0

@onready var m_drill: CharacterBody2D = $Drill
@onready var m_world: Node2D = $World
@onready var m_vision_overlay: Node = $VisionLayer/DarknessMask
@onready var m_depth_label: Label = $UILayer/DepthLabel
@onready var m_chunks_label: Label = $UILayer/ChunksLabel
@onready var m_fps_label: Label = $UILayer/FpsLabel
@onready var m_aim_label: Label = $UILayer/AimLabel
@onready var m_speed_slider: HSlider = $UILayer/SpeedPanel/SpeedSlider
@onready var m_speed_value_label: Label = $UILayer/SpeedPanel/SpeedValueLabel
@onready var m_fuel_bar: ProgressBar = $UILayer/FuelPanel/FuelBar
@onready var m_fuel_label: Label = $UILayer/FuelPanel/FuelLabel
@onready var m_return_button: Button = $UILayer/ReturnButton
@onready var m_tile_hp_debug_check: CheckBox = $UILayer/DebugPanel/TileHpDebugCheck
@onready var m_infinite_fuel_debug_check: CheckBox = $UILayer/DebugPanel/InfiniteFuelDebugCheck
@onready var m_super_mine_debug_check: CheckBox = $UILayer/DebugPanel/SuperMineDebugCheck
@onready var m_run_inventory_panel: RunInventoryPanel = $UILayer/RunInventoryPanel

var m_run_ended: bool = false


func _ready() -> void:
	print("Main ready (2-2: drill input move)")
	m_speed_slider.value_changed.connect(_on_speed_slider_changed)
	m_speed_slider.value = DEFAULT_MOVE_SPEED_PX
	_on_speed_slider_changed(m_speed_slider.value)
	m_drill.move_speed = m_move_speed_px
	m_return_button.pressed.connect(_on_return_button_pressed)
	m_drill.run_end_fuel_depleted.connect(_on_run_end_fuel_depleted)
	m_tile_hp_debug_check.toggled.connect(_on_tile_hp_debug_toggled)
	m_tile_hp_debug_check.button_pressed = m_drill.debug_show_tile_hp
	m_infinite_fuel_debug_check.toggled.connect(_on_infinite_fuel_debug_toggled)
	m_infinite_fuel_debug_check.button_pressed = m_drill.debug_infinite_fuel
	m_super_mine_debug_check.toggled.connect(_on_super_mine_debug_toggled)
	m_super_mine_debug_check.button_pressed = m_drill.debug_super_mine_damage

	_update_hud()


func _process(_delta: float) -> void:
	if not m_run_ended:
		m_drill.move_speed = m_move_speed_px
	_update_vision_overlay()
	_update_hud()


func _update_vision_overlay() -> void:
	if m_vision_overlay == null:
		return
	if m_vision_overlay.has_method("set_vision_radius"):
		m_vision_overlay.call("set_vision_radius", StatSystem.get_final(&"vision_radius"))
	if m_vision_overlay.has_method("set_darkness_alpha"):
		m_vision_overlay.call("set_darkness_alpha", StatSystem.get_final(&"vision_darkness_alpha"))
	if m_vision_overlay.has_method("set_center_screen_pos"):
		m_vision_overlay.call("set_center_screen_pos", get_viewport_rect().size * 0.5)


func _on_return_button_pressed() -> void:
	if m_run_ended:
		return
	_request_run_end(END_REASON_RETURN_TO_HUB)


func _on_run_end_fuel_depleted() -> void:
	_request_run_end(END_REASON_FUEL_DEPLETED)


func _request_run_end(reason: StringName) -> void:
	if m_run_ended:
		return
	m_run_ended = true
	m_drill.set_input_locked(true)
	m_speed_slider.editable = false
	m_tile_hp_debug_check.disabled = true
	m_infinite_fuel_debug_check.disabled = true
	m_super_mine_debug_check.disabled = true
	m_return_button.disabled = true
	run_end_requested.emit(reason)


func _on_speed_slider_changed(value: float) -> void:
	m_move_speed_px = value
	m_speed_value_label.text = "%d px/s" % int(round(value))


func _on_tile_hp_debug_toggled(enabled: bool) -> void:
	m_drill.debug_show_tile_hp = enabled


func _on_infinite_fuel_debug_toggled(enabled: bool) -> void:
	m_drill.debug_infinite_fuel = enabled


func _on_super_mine_debug_toggled(enabled: bool) -> void:
	m_drill.debug_super_mine_damage = enabled


func _update_hud() -> void:
	var depth_m := m_drill.position.y / float(TILE_SIZE_PX)
	m_max_depth_m = maxf(m_max_depth_m, depth_m)
	m_depth_label.text = "깊이: %.1f m" % depth_m
	m_fps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())
	if m_world.has_method("get_active_chunk_summary"):
		m_chunks_label.text = m_world.get_active_chunk_summary()
	var parts: Array[String] = []
	if m_drill.has_method("get_aim_debug_string"):
		parts.append(m_drill.get_aim_debug_string())
	if m_drill.has_method("get_status_debug_string"):
		parts.append(m_drill.get_status_debug_string())
	if m_drill.has_method("get_speed_debug_string"):
		parts.append(m_drill.get_speed_debug_string())
	if m_drill.has_method("get_fuel_cost_debug_string"):
		parts.append(m_drill.get_fuel_cost_debug_string())
	if m_drill.has_method("get_mining_debug_string"):
		parts.append(m_drill.get_mining_debug_string())
	if parts.size() > 0:
		m_aim_label.text = "\n".join(parts)

	_update_fuel_hud()
	m_run_inventory_panel.refresh(GameState.run_inventory, GameState.run_display)


func _update_fuel_hud() -> void:
	var fuel_max: float = StatSystem.get_final(&"fuel_max")
	var fuel: float = m_drill.fuel
	m_fuel_bar.max_value = fuel_max
	m_fuel_bar.value = clampf(fuel, 0.0, fuel_max)
	if m_drill.debug_infinite_fuel:
		m_fuel_label.text = "%.1f / %.1f (∞)" % [fuel, fuel_max]
	else:
		m_fuel_label.text = "%.1f / %.1f" % [fuel, fuel_max]
	if not m_drill.debug_infinite_fuel and fuel <= 0.0 and not m_run_ended:
		_on_run_end_fuel_depleted()


func get_max_depth_m() -> float:
	return m_max_depth_m

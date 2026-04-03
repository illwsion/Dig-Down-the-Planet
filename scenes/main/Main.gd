extends Node2D

## 이동/조준은 Drill에서 처리: 마우스 왼쪽 홀드 시 전진 + 마우스 방향으로 천천히 회전(±30°). Main은 HUD·슬라이더.

const TILE_SIZE_PX := 32
const DEFAULT_MOVE_SPEED_PX := 400.0

var m_move_speed_px: float = DEFAULT_MOVE_SPEED_PX

@onready var m_drill: CharacterBody2D = $Drill
@onready var m_world: Node2D = $World
@onready var m_depth_label: Label = $UILayer/DepthLabel
@onready var m_chunks_label: Label = $UILayer/ChunksLabel
@onready var m_fps_label: Label = $UILayer/FpsLabel
@onready var m_aim_label: Label = $UILayer/AimLabel
@onready var m_speed_slider: HSlider = $UILayer/SpeedPanel/SpeedSlider
@onready var m_speed_value_label: Label = $UILayer/SpeedPanel/SpeedValueLabel


func _ready() -> void:
	print("Main ready (2-2: drill input move)")
	m_speed_slider.value_changed.connect(_on_speed_slider_changed)
	m_speed_slider.value = DEFAULT_MOVE_SPEED_PX
	_on_speed_slider_changed(m_speed_slider.value)
	m_drill.move_speed = m_move_speed_px
	_update_hud()


func _process(_delta: float) -> void:
	m_drill.move_speed = m_move_speed_px
	_update_hud()


func _on_speed_slider_changed(value: float) -> void:
	m_move_speed_px = value
	m_speed_value_label.text = "%d px/s" % int(round(value))


func _update_hud() -> void:
	var depth_m := m_drill.position.y / float(TILE_SIZE_PX)
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
	if m_drill.has_method("get_mining_debug_string"):
		parts.append(m_drill.get_mining_debug_string())
	if parts.size() > 0:
		m_aim_label.text = "\n".join(parts)

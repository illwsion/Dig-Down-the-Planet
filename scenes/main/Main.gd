extends Node2D

## 1-4: CameraTarget을 월드 기준점으로 두고 방향키로 이동. Camera2D는 타깃의 자식이라 같이 이동. World 청크 동기화는 타깃 Y 기준.
## 시작: CameraTarget (0, 0) = 지면 맨 위, 깊이 0m.
## 1-5: FPS 표시, 오른쪽 상단 슬라이더로 이동 속도 조절.

const TILE_SIZE_PX := 32
const DEFAULT_PAN_SPEED_PX := 400.0

var m_pan_speed_px: float = DEFAULT_PAN_SPEED_PX

@onready var m_camera_target: Node2D = $CameraTarget
@onready var m_world: Node2D = $World
@onready var m_depth_label: Label = $UILayer/DepthLabel
@onready var m_chunks_label: Label = $UILayer/ChunksLabel
@onready var m_fps_label: Label = $UILayer/FpsLabel
@onready var m_speed_slider: HSlider = $UILayer/SpeedPanel/SpeedSlider
@onready var m_speed_value_label: Label = $UILayer/SpeedPanel/SpeedValueLabel


func _ready() -> void:
	print("Main ready (1-5: FPS + speed slider)")
	m_speed_slider.value_changed.connect(_on_speed_slider_changed)
	m_speed_slider.value = DEFAULT_PAN_SPEED_PX
	_on_speed_slider_changed(m_speed_slider.value)
	_update_hud()


func _process(delta: float) -> void:
	var dy := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		dy -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		dy += 1.0
	if dy != 0.0:
		m_camera_target.position.y += dy * m_pan_speed_px * delta
	_update_hud()


func _on_speed_slider_changed(value: float) -> void:
	m_pan_speed_px = value
	m_speed_value_label.text = "%d px/s" % int(round(value))


func _update_hud() -> void:
	var depth_m := m_camera_target.position.y / float(TILE_SIZE_PX)
	m_depth_label.text = "깊이: %.1f m" % depth_m
	m_fps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())
	if m_world.has_method("get_active_chunk_summary"):
		m_chunks_label.text = m_world.get_active_chunk_summary()

extends ColorRect

## 화면 전체 어둠 마스크의 셰이더 파라미터를 갱신한다.
## 씬 연결은 Main.tscn에서 별도로 진행한다.

@export var vision_radius_px: float = 144.0
@export_range(0.0, 1.0, 0.01) var darkness_alpha: float = 0.94

var m_center_screen_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_full_rect()
	_set_center_to_viewport_middle()
	_apply_shader_params()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_full_rect()
		_apply_shader_params()


func set_vision_radius(radius_px: float) -> void:
	vision_radius_px = maxf(radius_px, 0.0)
	_apply_shader_params()


func set_darkness_alpha(alpha: float) -> void:
	darkness_alpha = clampf(alpha, 0.0, 1.0)
	_apply_shader_params()


func set_center_screen_pos(pos: Vector2) -> void:
	m_center_screen_pos = pos
	_apply_shader_params()


func _update_full_rect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _set_center_to_viewport_middle() -> void:
	var viewport_rect := get_viewport_rect()
	m_center_screen_pos = viewport_rect.size * 0.5


func _apply_shader_params() -> void:
	var shader_material := material as ShaderMaterial
	if shader_material == null:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var center_uv := Vector2(
		m_center_screen_pos.x / viewport_size.x,
		m_center_screen_pos.y / viewport_size.y
	)

	shader_material.set_shader_parameter("center_uv", center_uv)
	shader_material.set_shader_parameter("viewport_size", viewport_size)
	shader_material.set_shader_parameter("vision_radius_px", vision_radius_px)
	shader_material.set_shader_parameter("darkness_alpha", darkness_alpha)

extends CharacterBody2D

## 바디 원점(0,0) = 드릴 끝.
## 조작: 마우스 왼쪽 **홀드** 시에만 전진 + 마우스 방향으로 초당 회전 제한 있게 회전.
## 수직 아래 기준 ±aim_limit_degrees 안에서만 조준. 카메라는 화면이 기울지 않게 로컬 회전 상쇄.

@onready var m_sprite: Sprite2D = $Sprite2D
@onready var m_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var m_camera: Camera2D = $Camera2D

## px/s — Main 슬라이더가 갱신.
var move_speed: float = 400.0

## 수직(아래)에서 벌어질 수 있는 최대 각(한쪽). 업그레이드로 넓히려면 export 유지.
@export var aim_limit_degrees: float = 30.0

## 초당 회전 한도(도). 업그레이드로 올리기 좋게 export.
@export var max_turn_degrees_per_second: float = 54.0

## 현재 조준각(라디안). 0 = 정면 아래, + = 마우스가 오른쪽에 있을 때(우하 방향으로 기울기).
var m_aim_angle: float = 0.0

const MOUSE_AIM_MIN_PX := 8.0


func _ready() -> void:
	# MVP용: 1번 레이어끼리 충돌되게 명시
	collision_layer = 1
	collision_mask = 1

	var tex := m_sprite.texture
	if tex == null:
		return
	var sz := tex.get_size()
	var w: float = sz.x
	var h: float = sz.y

	m_sprite.centered = true
	m_sprite.position = Vector2(0, -h * 0.5)

	var poly := ConvexPolygonShape2D.new()
	var half_top: float = w * 0.5
	poly.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(-half_top, -h),
		Vector2(half_top, -h),
	])
	m_collision_shape.shape = poly
	_sync_rotation_from_aim()


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("drill_down"):
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() >= MOUSE_AIM_MIN_PX:
			var desired := atan2(to_mouse.x, to_mouse.y)
			var lim := deg_to_rad(aim_limit_degrees)
			desired = clampf(desired, -lim, lim)
			var step := deg_to_rad(max_turn_degrees_per_second) * delta
			m_aim_angle = move_toward(m_aim_angle, desired, step)

		var forward := Vector2(sin(m_aim_angle), cos(m_aim_angle))
		velocity = forward * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_sync_rotation_from_aim()


func _sync_rotation_from_aim() -> void:
	# 스프라이트/드릴 끝의 \"아래 방향\" 기준이 목표 각과 부호가 반대로 보일 때가 있어 시각만 부호를 반전한다.
	# 이동 벡터(forward)는 유지하고, 회전만 반전해서 끝이 마우스 반대가 되지 않게 한다.
	rotation = -m_aim_angle
	if m_camera:
		m_camera.rotation = -rotation

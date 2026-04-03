extends CharacterBody2D

## 바디 원점(0,0) = 드릴 끝(tip). 회전 축도 tip이므로 월드에서의 tip은 [method get_tip_global_position]과 동일.
## 채굴·접촉 반경(`mine_*`)의 기준점은 항상 이 tip 월드 좌표 하나로 고정한다 (3-1).
## 조작: 마우스 왼쪽 홀드 시에만 전진 + 마우스 방향으로 초당 회전 제한 있게 회전.
## 수직 아래 기준 ±aim_angle_limit_deg 안에서만 조준. 카메라는 화면이 기울지 않게 로컬 회전 상쇄.

@onready var m_sprite: Sprite2D = $Sprite2D
@onready var m_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var m_camera: Camera2D = $Camera2D

## px/s — Main 슬라이더가 갱신. 매 프레임 `move_speed_max` 이하로 클램프.
var move_speed: float = 400.0

## 채굴: 접두 `mine_*` (MVP_DEVELOPMENT_PLAN.md 표와 동일). 기준점 = [method get_tip_global_position].
@export var debug_draw_mine_radii: bool = true
@export var mine_radius: float = 20.0
@export var mine_contact_radius: float = 10.0
@export_range(0.05, 10.0, 0.01) var mine_tick_interval: float = 0.15
@export var mine_damage_per_tick: float = 1.0

## 이동: 접두 `move_*` — 가속은 연료/채굴 로직과 함께 적용 예정.
@export var move_speed_max: float = 400.0
@export var move_acceleration: float = 1200.0

## 연료: 접두 `fuel_*`.
@export var fuel_max: float = 100.0
@export var fuel_drain_per_second: float = 5.0

## 현재 연료. 소모 정책은 구현 시 홀드/이동 조건에 맞춤.
var fuel: float = 0.0

## 조준: 접두 `aim_*`.
@export var aim_angle_limit_deg: float = 30.0
@export var aim_turn_max_deg_per_sec: float = 54.0

## 현재 조준각(라디안). 0 = 정면 아래, + = 마우스가 오른쪽에 있을 때(우하 방향으로 기울기).
var m_aim_angle: float = 0.0

const MOUSE_AIM_MIN_PX := 8.0

enum DrillStatus { IDLE, MOVING, DIGGING }

## 3-3: 홀드·접촉 원 안 채굴 대상 타일 유무로 갱신.
var drill_status: DrillStatus = DrillStatus.IDLE


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
	fuel = fuel_max
	_sync_rotation_from_aim()


func _physics_process(delta: float) -> void:
	move_speed = minf(move_speed, move_speed_max)
	if Input.is_action_pressed("drill_down"):
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() >= MOUSE_AIM_MIN_PX:
			var desired := atan2(to_mouse.x, to_mouse.y)
			var lim := deg_to_rad(aim_angle_limit_deg)
			desired = clampf(desired, -lim, lim)
			var step := deg_to_rad(aim_turn_max_deg_per_sec) * delta
			m_aim_angle = move_toward(m_aim_angle, desired, step)

		var forward := Vector2(sin(m_aim_angle), cos(m_aim_angle))
		velocity = forward * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_sync_rotation_from_aim()
	_update_drill_status()


func _update_drill_status() -> void:
	if not Input.is_action_pressed("drill_down"):
		drill_status = DrillStatus.IDLE
		return
	var world: Node = get_parent().get_node_or_null("World") if get_parent() else null
	if world != null and world.has_method("has_mineable_tile_in_circle"):
		if world.has_mineable_tile_in_circle(get_tip_global_position(), mine_contact_radius):
			drill_status = DrillStatus.DIGGING
			return
	drill_status = DrillStatus.MOVING


func _sync_rotation_from_aim() -> void:
	# 스프라이트/드릴 끝의 \"아래 방향\" 기준이 목표 각과 부호가 반대로 보일 때가 있어 시각만 부호를 반전한다.
	# 이동 벡터(forward)는 유지하고, 회전만 반전해서 끝이 마우스 반대가 되지 않게 한다.
	rotation = -m_aim_angle
	if m_camera:
		m_camera.rotation = -rotation


## Phase 3 채굴·접촉 원/거리 계산의 유일한 기준점(월드 좌표).
func get_tip_global_position() -> Vector2:
	return global_position


func get_aim_debug_string() -> String:
	var aim_deg := rad_to_deg(m_aim_angle)
	var holding := Input.is_action_pressed("drill_down")
	var holding_str := "ON" if holding else "OFF"
	return "조준각: %.1f° (±%.0f°) 홀드:%s" % [aim_deg, aim_angle_limit_deg, holding_str]


func get_mining_debug_string() -> String:
	var t := get_tip_global_position()
	return "tip:(%.0f,%.0f) mine_r:%.0f contact_r:%.0f tick:%.2fs dmg:%.1f" % [
		t.x, t.y, mine_radius, mine_contact_radius, mine_tick_interval, mine_damage_per_tick,
	]


func get_status_debug_string() -> String:
	match drill_status:
		DrillStatus.IDLE:
			return "상태: idle"
		DrillStatus.MOVING:
			return "상태: moving"
		DrillStatus.DIGGING:
			return "상태: digging"
		_:
			return "상태: ?"

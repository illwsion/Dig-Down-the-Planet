extends Area2D

## 월드에 스폰되는 드롭 아이템.
## 픽업 판정 시 run_inventory에 즉시 추가.
## 아이콘은 BOUNCE → FLY 애니메이션 후 드릴 중심에서 소멸.

#region 물리 상수
const c_Gravity: float        = 500.0   # px/s²
const c_MaxFallSpeed: float   = 300.0   # px/s
const c_DespawnDistance: float = 900.0  # 플레이어 거리 초과 시 자동 소멸 (px)
const c_LandCheckRadius: float = 4.0
const c_FootOffsetY: float     = 20.0
#endregion

#region 픽업 애니메이션 상수
## BOUNCE: 드릴 반대 방향으로 튕겨나가는 시간 (초)
const c_BounceDuration: float   = 0.3
## BOUNCE: 초기 튕김 속도 (px/s)
const c_BounceSpeed: float      = 130.0
## FLY: 드릴을 향해 빨려드는 초기 속도 (px/s)
const c_FlyInitialSpeed: float  = 80.0
## FLY: 가속도 (px/s²)
const c_FlyAcceleration: float  = 2000.0
## FLY: 최대 속도 (px/s)
const c_FlyMaxSpeed: float      = 1400.0
## FLY: 이 거리 이하면 도달 판정 → 소멸 (px)
const c_FlyArrivalDist: float   = 8.0
#endregion

@onready var m_sprite: Sprite2D = $Sprite2D

var item_id: StringName = &""
var count: int = 1
var pickup_radius: float = 80.0

#region 물리 상태
var m_velocity_y: float = 0.0
var m_velocity_x: float = 0.0
var m_bob_phase: float  = 0.0
#endregion

#region 픽업 애니메이션 상태
enum State { PHYSICS, BOUNCE, FLY }
var m_state: State = State.PHYSICS

var m_bounce_timer: float = 0.0
var m_bounce_dir: Vector2 = Vector2.ZERO
var m_fly_speed: float    = 0.0
#endregion


func _ready() -> void:
	add_to_group("drop_items")


func _process(delta: float) -> void:
	match m_state:
		State.PHYSICS:
			_apply_gravity(delta)
			_update_bob(delta)
			_check_pickup()
			_check_despawn()
		State.BOUNCE:
			_update_bounce(delta)
		State.FLY:
			_update_fly(delta)


## 타일 파괴 직후 Chunk에서 호출.
func setup(_item_id: StringName, _count: int, _spawn_pos: Vector2) -> void:
	item_id = _item_id
	count   = _count
	global_position = _spawn_pos

	m_velocity_x = randf_range(-80.0, 80.0)
	m_velocity_y = randf_range(-180.0, -80.0)

	var def: ItemDef = ItemDatabase.get_def(item_id)
	if def != null and def.icon != null:
		m_sprite.texture = def.icon


#region 물리

func _apply_gravity(delta: float) -> void:
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		return
	var foot_pos: Vector2 = global_position + Vector2(0.0, c_FootOffsetY)
	if world.has_mineable_tile_in_circle(foot_pos, c_LandCheckRadius) and m_velocity_y >= 0.0:
		m_velocity_y = 0.0
		m_velocity_x = 0.0
		return
	m_velocity_y = minf(m_velocity_y + c_Gravity * delta, c_MaxFallSpeed)
	global_position.y += m_velocity_y * delta
	m_velocity_x = move_toward(m_velocity_x, 0.0, 200.0 * delta)
	global_position.x += m_velocity_x * delta


func _update_bob(delta: float) -> void:
	if m_velocity_y != 0.0 or absf(m_velocity_x) > 1.0:
		m_bob_phase = 0.0
		m_sprite.position.y = 0.0
		return
	m_bob_phase += delta * TAU
	m_sprite.position.y = sin(m_bob_phase) * 3.5


func _check_despawn() -> void:
	var drill: Node = get_tree().get_first_node_in_group("drill")
	if drill == null:
		return
	if global_position.distance_to(drill.get_tip_global_position()) > c_DespawnDistance:
		queue_free()

#endregion


#region 픽업 애니메이션

func _check_pickup() -> void:
	var drill: Node = get_tree().get_first_node_in_group("drill")
	if drill == null:
		return
	if global_position.distance_to(drill.get_tip_global_position()) > pickup_radius:
		return
	if not GameState.run_inventory.can_add(item_id):
		return

	# 데이터 즉시 반영
	GameState.run_inventory.add_item(item_id, count)

	# BOUNCE 페이즈 시작: 드릴 반대 방향으로 튕김
	var away: Vector2 = (global_position - drill.get_tip_global_position()).normalized()
	if away == Vector2.ZERO:
		away = Vector2(randf_range(-1.0, 1.0), -1.0).normalized()
	m_bounce_dir  = away
	m_bounce_timer = 0.0
	m_velocity_x  = 0.0
	m_velocity_y  = 0.0
	m_state = State.BOUNCE


func _update_bounce(delta: float) -> void:
	m_bounce_timer += delta
	# easeOut: 시간이 지날수록 감속
	var t: float     = clampf(m_bounce_timer / c_BounceDuration, 0.0, 1.0)
	var speed: float = c_BounceSpeed * (1.0 - t)
	global_position += m_bounce_dir * speed * delta

	if m_bounce_timer >= c_BounceDuration:
		m_fly_speed = c_FlyInitialSpeed
		m_state = State.FLY


func _update_fly(delta: float) -> void:
	var drill: Node = get_tree().get_first_node_in_group("drill")
	if drill == null:
		queue_free()
		return

	var target: Vector2 = drill.get_tip_global_position()
	var dist: float     = global_position.distance_to(target)

	if dist <= c_FlyArrivalDist:
		GameState.confirm_pickup(item_id, count)
		queue_free()
		return

	m_fly_speed = minf(m_fly_speed + c_FlyAcceleration * delta, c_FlyMaxSpeed)
	global_position += (target - global_position).normalized() * m_fly_speed * delta

#endregion

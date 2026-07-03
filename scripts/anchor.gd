## 船锚：抛入海水后在目标距离处定锚，供船只沿绳索拉动
class_name Anchor
extends Node2D

# 锚在水中定住时发出（world_pos 为定锚世界坐标）
signal stuck(world_pos: Vector2, anchor: Anchor)
# 锚被收回或销毁时发出
signal retracted

# 锚在水中飞行的速度
@export var fly_speed: float = 520.0
# 最远可抛锚距离（相对船只）
@export var max_water_range: float = 300.0
# 最近定锚距离，防止锚落在船旁过近
@export var min_water_range: float = 56.0

var owner_ship: Node2D = null
var velocity: Vector2 = Vector2.ZERO
var is_stuck: bool = false
# 抛锚方向（归一化）
var _set_direction: Vector2 = Vector2.RIGHT
# 从船只出发、沿抛锚方向到达定锚点的距离
var _target_distance: float = 0.0
# 抛锚时船只的位置，作为距离计算基准
var _ship_origin: Vector2 = Vector2.ZERO


## 从 from_pos 出发，朝 target_pos 方向抛锚
func launch(from_pos: Vector2, target_pos: Vector2, ship: Node2D) -> void:
	owner_ship = ship
	_ship_origin = ship.global_position
	global_position = from_pos

	var to_target := target_pos - _ship_origin
	if to_target.length_squared() < 1.0:
		to_target = Vector2.RIGHT

	_set_direction = to_target.normalized()
	# 实际定锚距离限制在 [min_water_range, max_water_range] 内
	_target_distance = clampf(to_target.length(), min_water_range, max_water_range)
	velocity = _set_direction * fly_speed
	is_stuck = false
	show()


## 收回锚并销毁节点
func retract() -> void:
	retracted.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if is_stuck:
		return

	var to_pos := global_position + velocity * delta
	# 沿抛锚方向投影，判断是否到达目标定锚距离
	var projected := (to_pos - _ship_origin).dot(_set_direction)

	if projected >= _target_distance:
		global_position = _ship_origin + _set_direction * _target_distance
		_set_in_water()
		return

	global_position = to_pos


## 在海水中的目标位置定锚
func _set_in_water() -> void:
	is_stuck = true
	velocity = Vector2.ZERO
	stuck.emit(global_position, self)
	queue_redraw()


## 定锚后绘制水面波纹提示
func _draw() -> void:
	if not is_stuck:
		return
	draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.72, 0.92, 0.35))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.55, 0.85, 0.98, 0.7), 2.0)

class_name Anchor
extends Node2D

signal stuck(world_pos: Vector2, anchor: Anchor)
signal retracted

@export var fly_speed: float = 520.0
@export var max_water_range: float = 300.0
@export var min_water_range: float = 56.0

var owner_ship: Node2D = null
var velocity: Vector2 = Vector2.ZERO
var is_stuck: bool = false
var _set_direction: Vector2 = Vector2.RIGHT
var _target_distance: float = 0.0
var _ship_origin: Vector2 = Vector2.ZERO


func launch(from_pos: Vector2, target_pos: Vector2, ship: Node2D) -> void:
	owner_ship = ship
	_ship_origin = ship.global_position
	global_position = from_pos

	var to_target := target_pos - _ship_origin
	if to_target.length_squared() < 1.0:
		to_target = Vector2.RIGHT

	_set_direction = to_target.normalized()
	_target_distance = clampf(to_target.length(), min_water_range, max_water_range)
	velocity = _set_direction * fly_speed
	is_stuck = false
	show()


func retract() -> void:
	retracted.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if is_stuck:
		return

	var to_pos := global_position + velocity * delta
	var projected := (to_pos - _ship_origin).dot(_set_direction)

	if projected >= _target_distance:
		global_position = _ship_origin + _set_direction * _target_distance
		_set_in_water()
		return

	global_position = to_pos


func _set_in_water() -> void:
	is_stuck = true
	velocity = Vector2.ZERO
	stuck.emit(global_position, self)
	queue_redraw()


func _draw() -> void:
	if not is_stuck:
		return
	draw_circle(Vector2.ZERO, 10.0, Color(0.35, 0.72, 0.92, 0.35))
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 24, Color(0.55, 0.85, 0.98, 0.7), 2.0)

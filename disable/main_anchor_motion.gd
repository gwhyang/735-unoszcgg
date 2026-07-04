extends Node2D

enum { DRIFT, SHOOT, TOWRAD }

@export_group("game message")

@export_group("move status")
@export var anchor_speed: float = 2000.0
@export var ideal_angular_speed: float = 8.6
@export var raise_distance: float = 30.0
@export var damp: float = 0.0
@export var min_accler: float = 700.0
@export var near_zero_speed: float = 5.0
@export var radial_epsilon: float = 0.01

@onready var ship: Area2D = %ship
@onready var anchor: Area2D = %anchor

var target: Vector2
var toward_mode: int = DRIFT
var vel: Vector2

var iradius: float
var iangular_speed: float


func _physics_process(delta: float) -> void:
	process_move(delta)

	if Input.is_action_just_pressed("fire_anchor"):
		target = get_global_mouse_position()
		toward_mode = SHOOT
		set_anchor(true)

		# If you want anchor flight time, remove this block and let SHOOT finish naturally.
		toward_mode = TOWRAD
		anchor.global_position = target
		iradius = (target - ship.global_position).length()
		iangular_speed = max(ideal_angular_speed, vel.length() / max(iradius, 1.0))
		return

	if Input.is_action_just_released("fire_anchor"):
		toward_mode = DRIFT
		set_anchor(false)
		return


func process_move(delta: float) -> void:
	if toward_mode == SHOOT:
		anchor.global_position = anchor.global_position.move_toward(target, anchor_speed * delta)
		if anchor.global_position.is_equal_approx(target):
			toward_mode = TOWRAD

	if toward_mode == TOWRAD:
		apply_anchor_motion(delta)

	ship.position += vel * delta


func apply_anchor_motion(delta: float) -> void:
	var to_anchor := anchor.global_position - ship.global_position
	var distance := to_anchor.length()
	if distance < raise_distance:
		toward_mode = DRIFT
		set_anchor(false)
		return

	var radial_dir := to_anchor / distance
	var radial_speed := vel.dot(radial_dir)

	if vel.length() <= near_zero_speed or radial_speed > radial_epsilon:
		# Acute angle or almost stopped: accelerate toward the anchor.
		vel += radial_dir * min_accler * delta
	elif radial_speed < -radial_epsilon:
		# Obtuse angle: remove the extra outward radial velocity, leaving tangential motion.
		vel -= radial_dir * radial_speed
	else:
		# Right angle: reset speed to the circular-orbit speed for the current radius.
		var tangent := radial_dir.orthogonal()
		if vel.dot(tangent) < 0.0:
			tangent = -tangent
		vel = tangent * distance * iangular_speed

	if damp > 0.0:
		vel -= vel * damp


func set_anchor(enable: bool) -> void:
	anchor.visible = enable
	anchor.monitoring = enable
	anchor.monitorable = enable
	if enable:
		anchor.global_position = ship.global_position

extends CharacterBody2D

const ANCHOR_SCENE := preload("res://scenes/anchor.tscn")

@export var water_drag: float = 1.4
@export var pull_force: float = 540.0
@export var max_speed: float = 360.0

@onready var rope: Line2D = $Rope

var active_anchor: Anchor = null


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("fire_anchor"):
		_handle_fire()

	if active_anchor and is_instance_valid(active_anchor) and active_anchor.is_stuck:
		_apply_anchor_pull(delta)
	elif active_anchor and not is_instance_valid(active_anchor):
		active_anchor = null

	if active_anchor == null or not active_anchor.is_stuck:
		velocity = velocity.lerp(Vector2.ZERO, water_drag * delta)

	velocity = velocity.limit_length(max_speed)
	move_and_slide()
	_align_to_motion()
	_update_rope()


func _align_to_motion() -> void:
	if velocity.length_squared() > 400.0:
		rotation = velocity.angle() - PI * 0.5


func _handle_fire() -> void:
	if active_anchor and is_instance_valid(active_anchor):
		active_anchor.retract()
		active_anchor = null
		return
	_fire_anchor(get_global_mouse_position())


func _fire_anchor(target_pos: Vector2) -> void:
	var anchor := ANCHOR_SCENE.instantiate() as Anchor
	get_tree().current_scene.get_node("Anchors").add_child(anchor)

	var to_mouse := target_pos - global_position
	if to_mouse.length_squared() < 1.0:
		to_mouse = Vector2.RIGHT
	var launch_dir := to_mouse.normalized()
	var launch_pos := global_position + launch_dir * 10.0

	anchor.launch(launch_pos, target_pos, self)
	anchor.stuck.connect(_on_anchor_stuck)
	anchor.retracted.connect(_on_anchor_retracted)
	active_anchor = anchor


func _on_anchor_stuck(_world_pos: Vector2, anchor: Anchor) -> void:
	active_anchor = anchor


func _on_anchor_retracted() -> void:
	active_anchor = null


func _apply_anchor_pull(delta: float) -> void:
	var anchor_pos := active_anchor.global_position
	var to_anchor := anchor_pos - global_position
	var distance := to_anchor.length()
	if distance < 24.0:
		active_anchor.retract()
		active_anchor = null
		return

	velocity += (to_anchor / distance) * pull_force * delta


func _update_rope() -> void:
	if active_anchor == null or not is_instance_valid(active_anchor) or not active_anchor.is_stuck:
		rope.visible = false
		return
	rope.visible = true
	rope.points = PackedVector2Array([Vector2.ZERO, to_local(active_anchor.global_position)])

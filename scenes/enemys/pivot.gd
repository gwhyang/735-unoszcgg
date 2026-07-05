extends Node2D
@export var is_rotate:bool = true
@export var rotation_offset:float = -0.5*PI
@export var min_move_distance:float = 0.1

var last_global_position:Vector2

func _ready() -> void:
	last_global_position = get_parent().global_position

func _process(delta: float) -> void:
	if not is_rotate:
		last_global_position = get_parent().global_position
		return
	var current_global_position:Vector2 = get_parent().global_position
	var displacement:Vector2 = current_global_position - last_global_position
	if displacement.length() >= min_move_distance:
		global_rotation = displacement.angle() + rotation_offset
	last_global_position = current_global_position

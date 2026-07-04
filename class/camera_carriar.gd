extends Node2D
class_name FloatCameraCarrier

@export var followed:Node2D
@export var max_diff:float = 120.0
@export var follow_frquency:float = 2.0
@export var follow_damp:float = 0.8
@export var follow_response:float = 0.0

var post_posi:Vector2
var follow_damp_point:FollowDampPoint2
var has_post_posi:bool = false

func _ready() -> void:
	var initial_relative_position := Vector2.ZERO
	if followed:
		initial_relative_position = global_position - followed.global_position
		post_posi = followed.global_position
		has_post_posi = true
	follow_damp_point = FollowDampPoint2.new(follow_frquency, follow_damp, follow_response, initial_relative_position)

func _physics_process(delta: float) -> void:
	
	if followed == null:
		return
	if follow_damp_point == null:
		var current_relative_position := global_position - followed.global_position
		follow_damp_point = FollowDampPoint2.new(follow_frquency, follow_damp, follow_response, current_relative_position)

	var followed_position := followed.global_position
	var ideal_relative_position := Vector2.ZERO
	var followed_displacement := Vector2.ZERO
	if has_post_posi:
		followed_displacement = followed_position - post_posi
	else:
		has_post_posi = true

	if not followed_displacement.is_zero_approx():
		ideal_relative_position = followed_displacement.normalized() * max_diff

	var followed_relative_position := follow_damp_point.update(delta, ideal_relative_position)
	global_position = followed_position + followed_relative_position
	post_posi = followed_position

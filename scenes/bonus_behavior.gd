extends "res://scenes/enemy_behavior.gd"

func _get_target() -> Vector2:
	if player == null or not is_instance_valid(player):
		player = null
		return _get_patrol_target()

	return _get_avoid_target()

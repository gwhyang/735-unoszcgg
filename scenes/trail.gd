extends Line2D
@export var is_drawing:bool = true
@export var max_point_count:int = 7
@export var points_per_second:float = 60.0

@export var ship: Node2D

var add_point_time:float = 0.0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_drawing:
		add_point_time += delta
		var add_interval :float= 1.0 / max(points_per_second, 0.001)
		while add_point_time >= add_interval:
			add_point_time -= add_interval
			if get_point_count() > max_point_count:
				remove_point(0)
			add_point(ship.global_position)
		points[-1] = ship.global_position
	else:
		add_point_time = 0.0
		if get_point_count() > 0:
			remove_point(0)
		

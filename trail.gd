extends Line2D
@export var is_drawing:bool = true
@export var max_point_count:int = 10

@onready var ship: Area2D = %ship


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_drawing:
		if get_point_count() > max_point_count:
			remove_point(0)
		add_point(ship.global_position,)
	else:
		if get_point_count() > 0:
			remove_point(0)
		

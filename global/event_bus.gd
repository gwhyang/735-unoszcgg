extends Node
signal hit(area:Area2D)

func hit_area(area:Area2D):
	hit.emit(area)

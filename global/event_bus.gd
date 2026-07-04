extends Node
signal hit(area:Area2D)
signal heal(heal_count:int)
func hit_area(area:Area2D):
	hit.emit(area)

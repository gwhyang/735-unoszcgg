extends Node
signal hit(area:Area2D)
signal heal(heal_count:int)
signal spawn_requested(scene:PackedScene, spawn_position:Vector2, spawn_rotation:float, spawn_scale:Vector2)

func hit_area(area:Area2D):
	hit.emit(area)

func spawn(scene:PackedScene, spawn_position:Vector2 = Vector2.INF, spawn_rotation:float = INF, spawn_scale:Vector2 = Vector2.INF) -> void:
	spawn_requested.emit(scene, spawn_position, spawn_rotation, spawn_scale)

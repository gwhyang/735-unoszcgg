extends Marker2D
class_name SummonPoint
@export var scene:PackedScene

func summon() -> Node2D:
	if scene == null:
		return null
	var node:= scene.instantiate() as Node2D
	if node == null:
		return null
	node.global_position = global_position
	get_parent().add_child(node)
	return node

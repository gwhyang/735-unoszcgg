extends Camera2D
class_name ProCamera2D

var shake_strength:float = 0
var tx:Vector2 = Vector2.RIGHT
var ty:Vector2 = Vector2.UP
var tposition:Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	shake(shake_strength)

func shake(strength:float):
	var org:Vector2 = Vector2(randf_range(-shake_strength,shake_strength),randf_range(-shake_strength,shake_strength))
	offset = tx*org.x + ty*org.y +tposition

extends Area2D


func _on_area_entered(area: Area2D) -> void:
	#死亡
	queue_free()

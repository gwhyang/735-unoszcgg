extends Node
@export_file_path("level*.tscn") var level:String


func _on_pressed() -> void:
	get_tree().change_scene_to_file(level)

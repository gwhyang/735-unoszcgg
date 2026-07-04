extends Node
@export_file_path("level") var level:String

func a():
	get_tree().change_scene_to_file("res://addons/soundmanager/Global/sound_manager.tscn")

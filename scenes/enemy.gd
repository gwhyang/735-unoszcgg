extends CharacterBody2D
class_name Enemy
@onready var sprite: Sprite2D = %Sprite

func on_free():
	pass

func destory():
	disableself()
	on_free()
	await get_tree().create_timer(3)
	queue_free()

func disableself():
	collision_layer = 0
	sprite.hide()
#TODO enmey ai

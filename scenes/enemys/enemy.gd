extends CharacterBody2D
class_name Enemy
@onready var sprite: Sprite2D = %Sprite
const EXPLOSION = preload("uid://8ohhsdu6b26b")

func on_free():
	EventBus.spawn(EXPLOSION,global_position)
	pass

func destory():
	disableself()
	on_free()
	if get_tree():
		await get_tree().create_timer(3)
	queue_free()

func disableself():
	collision_layer = 0
	sprite.hide()

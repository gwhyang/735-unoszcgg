extends Node2D
enum {DRIFT,SHOOT,TOWRAD}

@export var anchor_speed:float = 200
@export var anchor_accler:float = 50

@onready var ship: Area2D = %ship
@onready var anchor: Area2D = %anchor

var target:Vector2
var toward_mode:int = DRIFT

func _physics_process(delta: float) -> void:
	if toward_mode == DRIFT:
		if Input.is_action_just_pressed("anchor"):
			target = get_global_mouse_position()
			toward_mode == SHOOT
			
		
	pass

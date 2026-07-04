extends Node2D
enum {DRIFT,SHOOT,TOWRAD}
@export_group("game message")
@export var high_speed:float = 2300
@export_group("move status")
@export var anchor_speed:float = 2000
@export var ideal_angular_speed:float = 1.6
@export var raise_distance:float = 30
@export var damp:float = 0.0
@export var min_accler:float = 70

@onready var ship: Player = %ship
@onready var anchor: Area2D = %anchor

var target:Vector2
var vel:Vector2

var iradius:float
var iangular_speed:float

func _ready() -> void:
	set_player(ship)
	
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("fire_anchor"):
		target = get_global_mouse_position()
		set_anchor(true)
		if true:
			anchor.global_position = target
			iradius = (target-ship.global_position).length()
			iangular_speed = max(ideal_angular_speed,vel.length()/iradius)
		return
	if Input.is_action_just_released("fire_anchor"):
		set_anchor(false)
		return

func set_anchor(enable:bool):
	anchor.visible = enable
	anchor.monitoring = enable
	anchor.monitorable = enable
	ship.is_floowing_anchor = enable
	if enable:
		anchor.global_position = ship.global_position

func set_player(player:Player):
	ship = player
	ship.game = self
	ship.anchor = anchor
	ship.high_speed = high_speed
	ship.damp = damp
	ship.min_accler = min_accler
	ship.raise_distance = raise_distance
	ship.ideal_angular_speed = ideal_angular_speed
	ship.iradius = iradius
	ship.iangular_speed = iangular_speed
	

func hit():
	pass
	
func hurt():
	pass

func _on_hithurt_area_entered(area: Area2D) -> void:
	if vel.length() > high_speed:
		hit()
	else:
		hurt()

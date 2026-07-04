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

@onready var ship: Area2D = %ship
@onready var anchor: Area2D = %anchor

var target:Vector2
var toward_mode:int = DRIFT
var vel:Vector2

var iradius:float
var iangular_speed:float

func _physics_process(delta: float) -> void:
	print(vel.length())
	process_move(delta)
	if Input.is_action_just_pressed("fire_anchor"):
		target = get_global_mouse_position()
		toward_mode = SHOOT
		set_anchor(true)
		if true:
			toward_mode = TOWRAD
			anchor.global_position = target
			iradius = (target-ship.global_position).length()
			iangular_speed = max(ideal_angular_speed,vel.length()/iradius)
		return
	if Input.is_action_just_released("fire_anchor"):
		toward_mode = DRIFT
		set_anchor(false)
		return
	if toward_mode == DRIFT:
		pass
		
	pass

func process_move(delta:float):
	var dir:Vector2
	if toward_mode == SHOOT:
		anchor.global_position=anchor.global_position.move_toward(target,anchor_speed*delta)
		if anchor.global_position.is_equal_approx(target):
			toward_mode = TOWRAD
	if toward_mode == TOWRAD:
		dir= anchor.global_position-ship.global_position
		if dir.length() < raise_distance:
			toward_mode = DRIFT
			return
		var dv:=(0.6+0.5*(cos(dir.angle_to(vel))))*ideal_angular_speed*ideal_angular_speed* delta* dir.normalized()/dir.length()#1这种加速快，回头有点笨的
		dv = dv.normalized() * max(dv.length(),min_accler)
		vel += dv
		vel -= vel*damp#可能要改一下，速度大量才阻尼
		
		#var dv=(0.6*abs(sin(dir.angle_to(vel))))*dir.normalized()*iradius*iangular_speed*iangular_speed #2试着按·默认圆周运动，并且使得趋向于之
		#dv = dv.normalized()*max(dv.length(),min_accler)
		#vel+= dv
	ship.position += vel*delta

func set_anchor(enable:bool):
	anchor.visible = enable
	anchor.monitoring = enable
	anchor.monitorable = enable
	if enable:
		anchor.global_position = ship.global_position
	

func hit():
	pass
func hurt():
	pass

func _on_hithurt_area_entered(area: Area2D) -> void:
	if vel.length() > high_speed:
		hit()
	else:
		hurt()

extends CharacterBody2D
class_name Player

signal hp_changed(new_hp:int)
signal hit_ship

@onready var game: Node2D = $".."
@onready var anchor: Area2D = %anchor
var high_speed:float = 2300
var damp:float = 0.0
var min_accler:float = 70
var is_floowing_anchor:bool = false
var raise_distance:float = 30
var collision_speed_loss:float = 0.84
var collision_max_speed:float = 240
var max_hp:int = 3
var hp:int = 3

var vel:Vector2

var iradius:float
var iangular_speed:float
var ideal_angular_speed:float = 1.6

func _physics_process(delta: float) -> void:
	process_move(delta)
	var collision:= move_and_collide(delta*vel)
	if collision:
		var speed_after_loss := vel.length() * (1.0 - collision_speed_loss)
		var speed_after_limit = min(speed_after_loss, collision_max_speed)
		vel = vel.bounce(collision.get_normal()).normalized() * speed_after_limit
		hurt()
func process_move(delta:float):
	var dir:Vector2
	if is_floowing_anchor:
		dir= anchor.global_position-global_position
		if dir.length() < raise_distance:
			game.set_anchor(false)
			return
		var dv:=(0.6+0.5*(cos(dir.angle_to(vel))))*ideal_angular_speed*ideal_angular_speed* delta* dir.normalized()/dir.length()#1这种加速快，回头有点笨的
		dv = dv.normalized() * max(dv.length(),min_accler)
		vel += dv
		vel -= vel*damp#可能要改一下，速度大量才阻尼
		
		#var dv=(0.6*abs(sin(dir.angle_to(vel))))*dir.normalized()*iradius*iangular_speed*iangular_speed #2试着按·默认圆周运动，并且使得趋向于之
		#dv = dv.normalized()*max(dv.length(),min_accler)
		#vel+= dv

func hit(area: Area2D):
	print("hit ship")
	hit_ship.emit()
	EventBus.hit_area(area)
	pass
	
func hurt():
	hp-=1
	hp_changed.emit(hp)
	game.set_anchor(false)
	print("hurt")
	pass

func _on_hithurt_area_entered(area: Area2D) -> void:
	if vel.length() > high_speed:
		hit(area)
	else:
		hurt()

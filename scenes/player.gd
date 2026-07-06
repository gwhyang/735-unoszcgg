extends CharacterBody2D
class_name Player

signal hp_changed(new_hp:int)
signal bounced
signal hit_ship
signal ship_hurt
signal fast
signal slow
@export var is_bouncing_hurt:bool = false
@export var fast_buffer:float = 0.2
@export var invincible_time:float = 1.0
@export var dizzy_time:float = 1.0
@export var invincible_flash_interval:float = 0.08

@onready var game: Node2D = $".."
@onready var anchor: Area2D = %anchor
@onready var shiptexture: Sprite2D = $shiptexture
@onready var dizzy: Label = $dizzy



var high_speed:float = 2300
var damp:float = 0.0
var min_accler:float = 70
var is_floowing_anchor:bool = false
var raise_distance:float = 30
var collision_speed_loss:float = 0.84
var collision_max_speed:float = 240
var max_hp:int = 3
var hp:int = 3:
	set(v):
		if v == hp:return
		if v<0:
			v = 0
		if v>max_hp:
			v = max_hp
		if v == hp:
			return
		hp = v
		hp_changed.emit(hp)
			

var vel:Vector2

var iradius:float
var iangular_speed:float
var ideal_angular_speed:float = 1.6
var invincible_timer:float = 0.0
var flash_timer:float = 0.0
var flash_enabled:bool = false
var is_fast:bool=false:
	set(v):
		if v==  is_fast:
			return
		is_fast = v
		Game.is_fast = is_fast
		if is_fast:
			fast.emit()
		else:
			slow.emit()
var fast_buffer_timer:float
var dizzy_timer:float:
	set(v):
		if v>0:
			dizzy.show()
		else :
			dizzy.hide()
		dizzy_timer = v


func _ready() -> void:
	_set_flash_amount(0.0)
	EventBus.heal.connect(
		func(v:int):
			hp+=v
			)

func _physics_process(delta: float) -> void:
	fast_buffer_timer -= delta
	dizzy_timer -= delta
	
	_process_invincible(delta)
	if hp>0:
		process_move(delta)
	var collision:= move_and_collide(delta*vel)
	if collision:
		var speed_after_loss := vel.length() * (1.0 - collision_speed_loss)
		var speed_after_limit = min(speed_after_loss, collision_max_speed)
		vel = vel.bounce(collision.get_normal()).normalized() * speed_after_limit
		bounced.emit()
		game.set_anchor(false)
		if dizzy_time>0:
			dizzy_timer = dizzy_time
		if is_bouncing_hurt:
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
	if vel.length()>high_speed:
		fast_buffer_timer = fast_buffer
	is_fast = fast_buffer_timer >=0

func hit(area: Area2D):
	print("hit ship")
	hit_ship.emit()
	EventBus.hit_area(area)
	SoundManager.sfx_play("kill")
	pass
	
func hurt():
	if invincible_timer > 0.0:
		return
	hp-=1
	game.set_anchor(false)
	ship_hurt.emit()
	SoundManager.sfx_play("hurt")
	_start_invincible()
	pass

func _start_invincible() -> void:
	invincible_timer = invincible_time
	flash_timer = 0.0
	flash_enabled = true
	_set_flash_amount(1.0)

func _process_invincible(delta:float) -> void:
	if invincible_timer <= 0.0:
		return

	invincible_timer -= delta
	flash_timer -= delta
	if flash_timer <= 0.0:
		flash_timer = invincible_flash_interval
		flash_enabled = not flash_enabled
		_set_flash_amount(1.0 if flash_enabled else 0.0)

	if invincible_timer <= 0.0:
		invincible_timer = 0.0
		flash_enabled = false
		_set_flash_amount(0.0)

func _set_flash_amount(amount:float) -> void:
	var shader_material:ShaderMaterial = shiptexture.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter("flash_amount", amount)

	

func _on_hithurt_area_entered(area: Area2D) -> void:
	if vel.length() > high_speed:
		hit(area)
	else:
		hurt()


func _on_bonus_area_entered(area: Area2D) -> void:
	hp+=1
	SoundManager.sfx_play("heal")
	hit(area)

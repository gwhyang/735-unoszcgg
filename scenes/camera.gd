extends ProCamera2D
@export var basic_zoom:Vector2=0.7*Vector2.ONE
@export var fast_zoom:float = 0.4
@export var slow_zoom:float = 1
@export var zoom_speed:float = 0.3
@export var hit_strength:float = 8
@export var hit_shake_time:float = 0.14
@export var hurt_strength:float = 13
@export var hurt_shake_time:float = 0.12
var target_zoom_scale:float = 1
var current_zoom:float = 1
var shake_tween:Tween

func _process(delta: float) -> void:
	zoom = current_zoom*basic_zoom
	current_zoom = move_toward(current_zoom,target_zoom_scale,delta*zoom_speed)
	super(delta)
	
func _on_ship_hit_ship() -> void:
	if shake_tween:
		if shake_tween.is_running():
			shake_tween.kill()
	#current_zoom = 1.2
	shake_strength = hit_strength
	#Engine.time_scale = 0.001
	#await  get_tree().create_timer(0.05,true,false,true).timeout
	#Engine.time_scale = 1
	shake_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	shake_tween.tween_property(self,"shake_strength",0,hit_shake_time)


func _on_ship_ship_hurt() -> void:
	if shake_tween:
		if shake_tween.is_running():
			shake_tween.kill()
	shake_strength = hurt_strength
	shake_tween = get_tree().create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	shake_tween.tween_property(self,"shake_strength",0,hurt_shake_time)


func _on_ship_fast() -> void:
	target_zoom_scale = fast_zoom
	pass # Replace with function body.


func _on_ship_slow() -> void:
	target_zoom_scale = slow_zoom
	pass # Replace with function body.

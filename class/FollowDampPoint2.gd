extends Node

class_name FollowDampPoint2

var _frquency:float
var _damp:float
var _response:float

var _k1:float
var _k2:float
var _k3:float
var _step_length_critical:float

var position_input_past:Vector2
var position:Vector2
var velocity:Vector2

func _init(frquency:float,damp:float,response:float,initial_position:Vector2):
	initialize(frquency,damp,response,initial_position)

func initialize(frquency:float,damp:float,response:float,initial_position:Vector2) ->FollowDampPoint2:
	_frquency = frquency
	_damp = damp
	_response = response
	
	position = initial_position
	position_input_past = initial_position
	velocity = Vector2.ZERO
	
	_k1 = _damp/(PI * _frquency)
	_k2 = 1/((2*PI*_frquency) ** 2)
	_k3 = _response * _damp / (2*PI*_frquency)
	_step_length_critical = 0.8 * frquency * (sqrt(4 * _k2 + _k1** 2) -_k1)
	
	return self

func update(delta:float,input_position:Vector2,input_velocity:Vector2 = Vector2.INF) -> Vector2:
	if input_velocity == Vector2.INF:
		input_velocity = (input_position - position_input_past) / delta
		position_input_past = input_position
	
	var interation:int = ceil(delta/_step_length_critical)
	var step_length:float = delta/interation
	for i in range(interation):
		position = position + velocity * step_length
		velocity = velocity + step_length * (input_position - position +
				_k3*input_velocity - _k1*velocity)/_k2
	
	return position

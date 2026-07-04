extends Node2D
class_name EnemyBehavior

enum BehaviorType {
	DIRECT,
	INTERCEPT,
	PINCER,
	NEAR_FAR,
}

@export var behavior_type:BehaviorType = BehaviorType.DIRECT
@export var speed:float = 70.0
@export var target_update_interval:float = 0.2
@export var patrol_start_radius:float = 80.0
@export var patrol_radius_growth:float = 12.0
@export var patrol_max_radius:float = 360.0
@export var patrol_reach_distance:float = 16.0
@export var predict_distance:float = 120.0
@export var short_predict_distance:float = 60.0
@export var predict_retry_count:int = 5
@export var predict_retry_step:float = 40.0
@export var near_far_distance:float = 150.0
@export var avoid_distance:float = 180.0
@export var navigation_check_distance:float = 16.0
@export var pincer_reference:Node2D

var player:Player
@onready var navigation_agent: NavigationAgent2D = %NavigationAgent

var enemy:CharacterBody2D
var spawn_position:Vector2
var patrol_target:Vector2
var current_target:Vector2
var target_update_timer:float = 0.0
var exist_time:float = 0.0
var has_patrol_target:bool = false

func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	spawn_position = enemy.global_position
	current_target = spawn_position
	navigation_agent.path_desired_distance = patrol_reach_distance
	navigation_agent.target_desired_distance = patrol_reach_distance


func _physics_process(delta: float) -> void:
	if enemy == null:
		return

	exist_time += delta
	target_update_timer -= delta
	if target_update_timer <= 0.0:
		target_update_timer = target_update_interval
		current_target = _get_target()
		navigation_agent.target_position = current_target

	var next_position := current_target
	if not navigation_agent.is_navigation_finished():
		next_position = navigation_agent.get_next_path_position()

	var direction := next_position - enemy.global_position
	if direction.is_zero_approx():
		enemy.velocity = Vector2.ZERO
	else:
		enemy.velocity = direction.normalized() * speed
	enemy.move_and_slide()


func _on_alert_area_body_entered(body: Node2D) -> void:
	if body is Player:
		player = body


func _on_alert_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null


func _get_target() -> Vector2:
	if player == null or not is_instance_valid(player):
		player = null
		return _get_patrol_target()

	if _should_avoid_player():
		return _get_avoid_target()

	match behavior_type:
		BehaviorType.DIRECT:
			return player.global_position
		BehaviorType.INTERCEPT:
			return _get_intercept_target()
		BehaviorType.PINCER:
			return _get_pincer_target()
		BehaviorType.NEAR_FAR:
			return _get_near_far_target()
		_:
			return player.global_position


func _should_avoid_player() -> bool:
	return player.is_fast and enemy.global_position.distance_to(player.global_position) < avoid_distance


func _get_avoid_target() -> Vector2:
	var away_direction := enemy.global_position - player.global_position
	if away_direction.is_zero_approx():
		away_direction = Vector2.RIGHT.rotated(randf() * TAU)
	return _get_valid_or_original_point(enemy.global_position + away_direction.normalized() * avoid_distance)


func _get_intercept_target() -> Vector2:
	var direction := _get_player_move_direction()
	if direction.is_zero_approx():
		return player.global_position

	for i in range(predict_retry_count):
		var distance := predict_distance + predict_retry_step * i
		var target := player.global_position + direction * distance
		if _is_point_on_navigation(target):
			return target
	return player.global_position


func _get_pincer_target() -> Vector2:
	var direction := _get_player_move_direction()
	var predict_point := player.global_position + direction * short_predict_distance
	var reference := _get_pincer_reference()
	if reference == null:
		return _get_intercept_target()

	var target := predict_point + (predict_point - reference.global_position)
	return _get_valid_or_original_point(target)


func _get_near_far_target() -> Vector2:
	if enemy.global_position.distance_to(player.global_position) >= near_far_distance:
		return player.global_position
	return _get_patrol_target()


func _get_player_move_direction() -> Vector2:
	if player.vel.is_zero_approx():
		return Vector2.ZERO
	return player.vel.normalized()


func _get_patrol_target() -> Vector2:
	if has_patrol_target and enemy.global_position.distance_to(patrol_target) > patrol_reach_distance:
		return patrol_target

	patrol_target = _make_patrol_target()
	has_patrol_target = true
	return patrol_target


func _make_patrol_target() -> Vector2:
	var radius :float= min(patrol_start_radius + exist_time * patrol_radius_growth, patrol_max_radius)
	for i in range(12):
		var local_offset := Vector2(
				randf_range(-radius, radius),
				randf_range(-radius, radius)
		)
		var target := spawn_position + local_offset
		if _is_point_on_navigation(target):
			return target
	return spawn_position


func _get_pincer_reference() -> Node2D:
	if pincer_reference != null and is_instance_valid(pincer_reference):
		return pincer_reference

	for node in get_tree().get_nodes_in_group("enemy"):
		if node != enemy and node is Node2D:
			return node
	return null


func _get_valid_or_original_point(point: Vector2) -> Vector2:
	if _is_point_on_navigation(point):
		return point
	var map := navigation_agent.get_navigation_map()
	if map.is_valid():
		return NavigationServer2D.map_get_closest_point(map, point)
	return point


func _is_point_on_navigation(point: Vector2) -> bool:
	var map := navigation_agent.get_navigation_map()
	if not map.is_valid():
		return true
	var closest_point := NavigationServer2D.map_get_closest_point(map, point)
	return closest_point.distance_to(point) <= navigation_check_distance

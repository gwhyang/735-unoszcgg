extends SummonPoint

@export var summon_interval:float = 3.0
@export var summon_ditter:float = 0.4

@onready var visible_on_screen_notifier:VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var countdown:float
var summoned_node:Node2D

func _ready() -> void:
	countdown = summon_interval+randf()*summon_ditter

func _process(delta: float) -> void:
	if _has_summoned_node():
		return

	countdown = max(countdown - delta, 0.0)
	if countdown > 0.0:
		return
	if visible_on_screen_notifier.is_on_screen():
		return

	summoned_node = summon()
	if summoned_node == null:
		return

	summoned_node.global_position = _get_random_position_in_visible_rect()
	countdown = summon_interval+randf()*summon_ditter

func _has_summoned_node() -> bool:
	if summoned_node == null:
		return false
	if is_instance_valid(summoned_node):
		return true
	summoned_node = null
	return false

func _get_random_position_in_visible_rect() -> Vector2:
	var rect := visible_on_screen_notifier.rect
	var local_position := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
	)
	return visible_on_screen_notifier.to_global(local_position)

extends Control
@onready var player: Player = %ship

@export var show_radius:float = 1200.0
@export var point_radius:float = 2.5
@export var border_width:float = 2.0
@export var background_color:Color = Color.BLACK
@export var border_color:Color = Color.WHITE
@export var enemy_color:Color = Color.RED
@export var bonus_color:Color = Color.GREEN
@export var cross_color:Color = Color(1.0, 1.0, 1.0, 0.35)
@export var cross_width:float = 1.0

func _ready() -> void:
	if player == null:
		player = _find_player()


func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
		if player == null:
			return

	var center:Vector2 = size * 0.5
	var minimap_radius :float= min(size.x, size.y) * 0.5 - border_width
	if minimap_radius <= 0.0:
		return

	draw_circle(center, minimap_radius, background_color)
	draw_line(center + Vector2.LEFT * minimap_radius, center + Vector2.RIGHT * minimap_radius, cross_color, cross_width)
	draw_line(center + Vector2.UP * minimap_radius, center + Vector2.DOWN * minimap_radius, cross_color, cross_width)
	_draw_group_points("enemy", enemy_color, center, minimap_radius)
	_draw_group_points("bnous", bonus_color, center, minimap_radius)
	draw_arc(center, minimap_radius, 0.0, TAU, 64, border_color, border_width)


func _draw_group_points(group_name:StringName, color:Color, center:Vector2, minimap_radius:float) -> void:
	for node:Node in get_tree().get_nodes_in_group(group_name):
		if node == player or not node is Node2D:
			continue
		var node_2d:Node2D = node as Node2D
		var relative_position:Vector2 = node_2d.global_position - player.global_position
		if relative_position.length() > show_radius:
			continue

		var minimap_position:Vector2 = center + relative_position / show_radius * minimap_radius
		draw_circle(minimap_position, point_radius, color)


func _find_player() -> Player:
	for node:Node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			return node

	var current_scene:Node = get_tree().current_scene
	if current_scene:
		var ship:Node = current_scene.get_node_or_null("%ship")
		if ship is Player:
			return ship
	return null

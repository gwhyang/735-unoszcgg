extends Node2D

class ChainDrawer:
	extends Node2D

	var level:Node

	func _process(delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if level != null:
			level.call("_draw_chain", self)

enum {DRIFT,SHOOT,TOWRAD}
@export_group("level_setting")
@export var target_kill_count:int = 10
@export_group("game message")
@export var high_speed:float = 2300
@export var max_hp:int =3
@export_group("move status")
@export var anchor_speed:float = 2000
@export var ideal_angular_speed:float = 1.6
@export var raise_distance:float = 30
@export var damp:float = 0.0
@export var min_accler:float = 70
@export_group("chain visual")
@export var chain_color:Color = Color(0.55, 0.55, 0.55, 1.0)
@export var chain_width:float = 2.0
@export var chain_curve_segments:int = 24
@export var chain_shake_amplitude_scale:float = 4.0
@export var chain_shake_frequency:float = 8.0
@export var chain_shake_damp:float = 5.0

@onready var ship: Player = %ship
@onready var anchor: Area2D = %anchor
@onready var hp_container: HPContainer = %HpContainer
@onready var kill_count_label: Label = %kill_count_label
@onready var finui_player: AnimationPlayer = %FinuiPlayer
@onready var speed_display: AnimationPlayer = %speed_display
@onready var speed_label: RichTextLabel = $"GameUI/VBoxContainer2/speed label"

@onready var glasses: TextureRect = $GameUI/glasses
@onready var margin: ColorRect = $GameUI/margin

var target:Vector2
var vel:Vector2

var iradius:float
var iangular_speed:float
var chain_shake_time:float = 0.0
var chain_shake_amplitude:float = 0.0
var chain_drawer:ChainDrawer
var current_count:int =0:
	set(v):
		current_count = v
		kill_count_label.text = "击杀： "+str(current_count)+"/"+str(target_kill_count)
var enable_input = true

const MENU:String = "res://ui/menu_1.tscn"


func _ready() -> void:
	get_tree().root.set_canvas_cull_mask_bit(1,false)
	if not EventBus.spawn_requested.is_connected(spawn):
		EventBus.spawn_requested.connect(spawn)
	_setup_chain_drawer()
	set_player(ship)
	hp_container.set_hp(max_hp)
	current_count = target_kill_count
	_update_speed_label()
	
func _process(delta: float) -> void:
	_update_speed_label()
	if anchor.visible:
		chain_shake_time += delta

func _physics_process(delta: float) -> void:
	if not enable_input:
		return
	if ship.dizzy_timer>0:
		return
	if Input.is_action_just_pressed("fire_anchor"):
		target = get_global_mouse_position()
		set_anchor(true)
		SoundManager.sfx_play("click")
		if true:
			anchor.global_position = target
			_start_chain_shake()
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
	ship.max_hp = max_hp
	ship.hp = max_hp

func spawn(scene:PackedScene, spawn_position:Vector2 = Vector2.INF, spawn_rotation:float = INF, spawn_scale:Vector2 = Vector2.INF) -> Node2D:
	if scene == null:
		return null

	var node:Node = scene.instantiate()
	if not node is Node2D:
		node.queue_free()
		return null

	var node_2d:Node2D = node as Node2D
	if spawn_position != Vector2.INF:
		node_2d.global_position = spawn_position
	if spawn_rotation != INF:
		node_2d.global_rotation = spawn_rotation
	if spawn_scale != Vector2.INF:
		node_2d.scale = spawn_scale

	add_child(node_2d)
	return node_2d

func _start_chain_shake() -> void:
	var chain_length:float = ship.global_position.distance_to(anchor.global_position)
	chain_shake_time = 0.0
	chain_shake_amplitude = sqrt(chain_length) * chain_shake_amplitude_scale

func _setup_chain_drawer() -> void:
	chain_drawer = ChainDrawer.new()
	chain_drawer.name = "ChainDrawer"
	chain_drawer.level = self
	chain_drawer.z_as_relative = false
	chain_drawer.z_index = 100
	chain_drawer.top_level = true
	add_child(chain_drawer)

func _draw_chain(drawer:Node2D) -> void:
	if not anchor.visible:
		return

	var start_position:Vector2 = drawer.to_local(ship.global_position)
	var end_position:Vector2 = drawer.to_local(anchor.global_position)
	var link_vector:Vector2 = end_position - start_position
	if link_vector.is_zero_approx():
		return

	var midpoint:Vector2 = (start_position + end_position) * 0.5
	var normal:Vector2 = link_vector.orthogonal().normalized()
	var shake_offset:float = chain_shake_amplitude * exp(-chain_shake_damp * chain_shake_time) * cos(TAU * chain_shake_frequency * chain_shake_time)
	var control_position:Vector2 = midpoint + normal * shake_offset
	var segment_count:int = max(chain_curve_segments, 1)
	var points:PackedVector2Array = PackedVector2Array()
	for i:int in range(segment_count + 1):
		var t:float = float(i) / float(segment_count)
		var inv_t:float = 1.0 - t
		var point:Vector2 = inv_t * inv_t * start_position + 2.0 * inv_t * t * control_position + t * t * end_position
		points.append(point)

	drawer.draw_polyline(points, chain_color, chain_width, true)

func _update_speed_label() -> void:
	var speed_value:int = roundi(ship.vel.length())
	var high_speed_value:int = roundi(high_speed)
	var speed_text:String = "速度：%d/%d" % [speed_value, high_speed_value]
	if speed_value > high_speed_value:
		speed_label.text = "[color=red]%s[/color]" % speed_text
	else:
		speed_label.text = "[color=white]%s[/color]" % speed_text
	
func win():
	finui_player.play("win")
	enable_input = false
	await finui_player.animation_finished
	get_tree().change_scene_to_file(MENU)
	
func lose():
	finui_player.play("lose")
	enable_input = false
	SoundManager.sfx_play("die")
	pass

func _on_ship_hit_ship() -> void:
	current_count -= 1
	if current_count<=0:
		win()


func _on_ship_hp_changed(new_hp: int) -> void:
	if new_hp == 0:
		lose()
	pass # Replace with function body.


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
	pass # Replace with function body.


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU)
	pass # Replace with function body.


func _on_setting_pressed() -> void:
	pass # Replace with function body.


func _on_ship_fast() -> void:
	speed_display.play("fast")
	pass # Replace with function body.


func _on_ship_slow() -> void:
	speed_display.play("slow")
	pass # Replace with function body.

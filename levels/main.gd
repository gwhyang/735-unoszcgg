extends Node2D
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

@onready var ship: Player = %ship
@onready var anchor: Area2D = %anchor
@onready var hp_container: HPContainer = %HpContainer
@onready var kill_count_label: Label = %kill_count_label
@onready var finui_player: AnimationPlayer = %FinuiPlayer
@onready var speed_display: AnimationPlayer = %speed_display

@onready var glasses: TextureRect = $GameUI/glasses
@onready var margin: ColorRect = $GameUI/margin

var target:Vector2
var vel:Vector2

var iradius:float
var iangular_speed:float
var current_count:int =0:
	set(v):
		current_count = v
		kill_count_label.text = str(current_count)+"/"+str(target_kill_count)
var enable_input = true

const MENU:String = "uid://cx1yr4eluys35"


func _ready() -> void:
	get_tree().root.set_canvas_cull_mask_bit(1,false)
	set_player(ship)
	hp_container.set_hp(max_hp)
	current_count = target_kill_count
	

func _physics_process(delta: float) -> void:
	if not enable_input:
		return
	if Input.is_action_just_pressed("fire_anchor"):
		target = get_global_mouse_position()
		set_anchor(true)
		SoundManager.sfx_play("click")
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
	ship.max_hp = max_hp
	ship.hp = max_hp
	
func win():
	finui_player.play("lose")
	enable_input = false
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

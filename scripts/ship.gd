## 海盗船：通过向海水抛锚并被绳索拉动来移动
extends CharacterBody2D

const ANCHOR_SCENE := preload("res://scenes/anchor.tscn")

# 海水阻力：未定锚时每帧衰减速度
@export var water_drag: float = 1.4
# 定锚后沿绳索被拉向锚点的力度
@export var pull_force: float = 540.0
# 最大航行速度
@export var max_speed: float = 360.0

@onready var rope: Line2D = $Rope

# 当前已发射、尚未收回的锚
var active_anchor: Anchor = null


func _physics_process(delta: float) -> void:
	# 鼠标左键：抛锚或收回锚
	if Input.is_action_just_pressed("fire_anchor"):
		_handle_fire()

	# 锚已在水中定住时，沿绳索拉动船只
	if active_anchor and is_instance_valid(active_anchor) and active_anchor.is_stuck:
		_apply_anchor_pull(delta)
	elif active_anchor and not is_instance_valid(active_anchor):
		active_anchor = null

	# 没有有效定锚时，速度受海水阻力影响逐渐归零
	if active_anchor == null or not active_anchor.is_stuck:
		velocity = velocity.lerp(Vector2.ZERO, water_drag * delta)

	velocity = velocity.limit_length(max_speed)
	move_and_slide()
	_align_to_motion()
	_update_rope()


## 根据移动方向旋转船体（仅视觉表现，不影响抛锚方向）
func _align_to_motion() -> void:
	if velocity.length_squared() > 400.0:
		rotation = velocity.angle() - PI * 0.5


## 处理抛锚/收锚：已有锚则收回，否则向鼠标位置抛出新锚
func _handle_fire() -> void:
	if active_anchor and is_instance_valid(active_anchor):
		active_anchor.retract()
		active_anchor = null
		return
	_fire_anchor(get_global_mouse_position())


## 实例化锚并朝鼠标方向发射（与船头朝向无关）
func _fire_anchor(target_pos: Vector2) -> void:
	var anchor := ANCHOR_SCENE.instantiate() as Anchor
	get_tree().current_scene.get_node("Anchors").add_child(anchor)

	var to_mouse := target_pos - global_position
	if to_mouse.length_squared() < 1.0:
		to_mouse = Vector2.RIGHT
	var launch_dir := to_mouse.normalized()
	# 从船体沿鼠标方向稍微偏移，避免锚生成在碰撞体内部
	var launch_pos := global_position + launch_dir * 10.0

	anchor.launch(launch_pos, target_pos, self)
	anchor.stuck.connect(_on_anchor_stuck)
	anchor.retracted.connect(_on_anchor_retracted)
	active_anchor = anchor


## 锚在水中定住时的回调
func _on_anchor_stuck(_world_pos: Vector2, anchor: Anchor) -> void:
	active_anchor = anchor


## 锚被收回或超时消失时的回调
func _on_anchor_retracted() -> void:
	active_anchor = null


## 定锚后持续向锚点施加拉力，靠近后自动收锚
func _apply_anchor_pull(delta: float) -> void:
	var anchor_pos := active_anchor.global_position
	var to_anchor := anchor_pos - global_position
	var distance := to_anchor.length()
	if distance < 24.0:
		active_anchor.retract()
		active_anchor = null
		return

	velocity += (to_anchor / distance) * pull_force * delta


## 更新连接船只与水中锚点的绳索显示
func _update_rope() -> void:
	if active_anchor == null or not is_instance_valid(active_anchor) or not active_anchor.is_stuck:
		rope.visible = false
		return
	rope.visible = true
	rope.points = PackedVector2Array([Vector2.ZERO, to_local(active_anchor.global_position)])

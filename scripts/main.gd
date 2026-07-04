## 主场景入口脚本（场景结构由 main.tscn 定义）
extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var lives_label: Label = $UI/HUD/LivesLabel
@onready var game_over_panel: PanelContainer = $UI/GameOverPanel
@onready var game_over_label: Label = $UI/GameOverPanel/GameOverLabel


func _ready() -> void:
	game_over_panel.visible = false
	ship.lives_changed.connect(_on_lives_changed)
	ship.died.connect(_on_ship_died)
	_on_lives_changed(ship.lives)


func _on_lives_changed(current_lives: int) -> void:
	lives_label.text = "生命: %d / %d" % [current_lives, ship.max_lives]


func _on_ship_died() -> void:
	game_over_label.text = "船只损毁！按 R 重新开始"
	game_over_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and ship.is_dead:
		get_tree().reload_current_scene()

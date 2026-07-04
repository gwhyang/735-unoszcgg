extends Area2D

signal hurt

func _ready() -> void:
	EventBus.hit.connect(on_hurt)

func on_hurt(area:Area2D):
	if area != self:
		return
	hurt.emit()

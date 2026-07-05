extends Enemy

func on_free():
	EventBus.heal.emit(1)
	EventBus.spawn(EXPLOSION,global_position)

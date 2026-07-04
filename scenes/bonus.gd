extends Enemy

func on_free():
	EventBus.heal.emit(1)

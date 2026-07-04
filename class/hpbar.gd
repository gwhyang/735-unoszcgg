extends HBoxContainer
class_name HPContainer
const HP = preload("uid://mvl7ilbpl71w")


func set_hp(hp:int):
	var children:=get_children()
	var diff = hp - children.size()
	if hp<0:
		hp = 0
	if diff>0:
		for i in diff:
			add_child(HP.instantiate())
	if diff<0:
		for i in -diff:
			children[i].queue_free()
			

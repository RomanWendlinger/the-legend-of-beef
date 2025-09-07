class_name XYMap

var elements:Dictionary = {}

func _init() -> void:
	pass
	
func get_element(position: Vector2i):
	if elements.has(position.x):
		if elements[position.x].has(position.y):
			return elements[position.x][position.y]
		else:
			return null
	else: 
		return null
		
func append(position: Vector2i, elem = true):
	
	if !elements.has(position.x): 
		elements[position.x] = {}
	elements[position.x][position.y] = elem

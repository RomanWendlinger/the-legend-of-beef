extends Node
class_name Room

static var max_room_number = 0

@export var top_left: Vector2i
@export var bottom_right: Vector2i
@export var center_position: Vector2i
@export var room_number: int
@export var no_monster_spawn := false

func _init() -> void:
	room_number = max_room_number
	if room_number == 0:
		no_monster_spawn = true
	max_room_number += 1
	print("room number ",room_number)
	
	SignalBus.start_map_close.connect(reset)
	
func reset() -> void:
	max_room_number = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

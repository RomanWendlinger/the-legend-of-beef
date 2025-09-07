extends Node
class_name RoomGenerator

@export_group("Walker settings")
@export var position: Vector2i
@export var direction: Vector2i
@export var min_walk_distance: int
@export var max_walk_distance: int
## the tile width of the corridor
@export var corridor_width: int = 1

@export_group("Room settings")
@export var existing_rooms: Array[Room]
@export var maximum_rooms: int
@export var min_room_size: int
@export var max_room_size: int

var groundTileMap = XYMap.new()



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.start_map_close.connect(reset)
	pass # Replace with function body.

func reset() -> void:
	existing_rooms = []


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# create walker
	#	position Vector2i
	#	direction Vector2i
	#	target TileMapLayer
	#	painted_atlas_id int
	#	existing_rooms
	#		top-left and bottom-right position
	#		array[Vector2i, Vector2i]
	#	maximum_rooms int
	#	min_walk_distance int
	#	max_walk_distance int
	# check if we are not at max_rooms yet
	# move walker a random distance between min_walk_distance and max_walk_distance
	# check if room is creatable
	# if true, create room
	# if not, move to
	#	either into the conflicting room if you can keep walking into it
	#	past that room if walking straight is possible
	#	check if merging the rooms is possible
	#		if possible, merge rooms
	#		move turn and move at random 
	#	start with "check if room is creatable" again
func create_rooms() -> void:
	create_room()
	turn_random_direction(true)
	while(existing_rooms.size() < maximum_rooms):
		var distance = randi_range(min_walk_distance, max_walk_distance)
		# walk distance and paint each cell
		while (distance > 0):
			# get 90° direction to draw the column
			var orthogonal_direction = Vector2i(direction.y * -1, direction.x)
			# move perpendicular to the actual direction (draw the width of the corridor), then move back half the width
			var orthogonal_position = position - (orthogonal_direction * floor(corridor_width / 2))
			for column in corridor_width:
				groundTileMap.append(orthogonal_position)
				orthogonal_position += orthogonal_direction
			position += direction
			distance -= 1
		create_room()

		turn_random_direction()
	#draw all the points
	
	

func create_room() -> void:
	var room_size_x = randi_range(min_room_size, max_room_size)
	var room_size_y = randi_range(min_room_size, max_room_size)
	var room_center_position = position
	# get top left corner
	position.x = position.x - floor(room_size_x /2) 
	position.y = position.y - floor(room_size_y /2) 
	# create new object now to make math easier
	var room = Room.new()
	room.top_left = position
	room.bottom_right = position + Vector2i(room_size_x, room_size_y)
	room.center_position = room_center_position
	existing_rooms.append(room)
	#draw room
	for row in room_size_y:
		# paint the whole row
		
		for column in room_size_x:
			groundTileMap.append(position)
			#target.set_cell(position, -1, painted_atlas_coords)
			# move one to the right after cell
			position += Vector2i.RIGHT
		# pull the position back to the left
		position.x -= room_size_x
		# get next row
		position += Vector2i.DOWN
	# rooms painted, lets get back into the center
	position = room_center_position

func turn_random_direction(true_random = false ) -> void:
	var turn: int
	# just set any direction
	if true_random:
		turn = randi_range(1, 4)
		match turn:
			1:
				direction = Vector2i(-1,0)
			2:
				direction = Vector2i(0,-1)
			3:
				direction = Vector2i(1,0)
			4:
				direction = Vector2i(0,1)
	# turn or keep going without going back
	else:
	# number of turns
		turn = randi_range(1, 3)
		# turn left
		if(turn == 1):
			direction = Vector2i(direction.y * -1, direction.x)
		# turn right
		if (turn == 3):
			direction = Vector2i(direction.y, direction.x * -1)

extends Node
class_name DestructibleSpawner

@export var destructible_scene: PackedScene = preload("res://items/destructibles/destructible_crate.tscn")
@export var min_destructibles_per_room := 1
@export var max_destructibles_per_room := 4
@export var spawn_margin := 32  # Distance from walls in pixels

func spawn_destructibles_in_room(room: Room) -> void:
	# Don't spawn in the first room
	if room.no_monster_spawn:
		return

	var num_destructibles = randi_range(min_destructibles_per_room, max_destructibles_per_room)

	# Calculate room bounds in world coordinates (tile size is 16)
	var tile_size = 16
	var room_min = Vector2(room.top_left.x * tile_size, room.top_left.y * tile_size) + Vector2(spawn_margin, spawn_margin)
	var room_max = Vector2(room.bottom_right.x * tile_size, room.bottom_right.y * tile_size) - Vector2(spawn_margin, spawn_margin)

	# Ensure we have valid spawn area
	if room_max.x <= room_min.x or room_max.y <= room_min.y:
		return

	for i in num_destructibles:
		var destructible = destructible_scene.instantiate()

		# Random position within the room bounds
		var spawn_pos = Vector2(
			randf_range(room_min.x, room_max.x),
			randf_range(room_min.y, room_max.y)
		)

		destructible.global_position = spawn_pos

		# Add to the scene tree
		get_tree().root.get_node("Main").call_deferred("add_child", destructible)

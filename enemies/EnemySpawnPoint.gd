extends Node2D
class_name EnemySpawnPoint

signal player_in_treshhold(spawner: EnemySpawnPoint)

@export var melee_spawnpoint := true
@export var flying_spawnpoint := true
@onready var in_room : Room
## distance to the player when the spawn is triggered in tiles´

var spawnpoint_already_triggered := false

func _ready() -> void:
	if in_room.no_monster_spawn:
		return
	SceneSwitcher.on_map_close_functions.append(queue_free)
	add_check_zone()
	
func add_check_zone() -> void:
	var check_zone = Area2D.new()
	var collisionShape2d = CollisionShape2D.new()
	collisionShape2d.shape = RectangleShape2D.new()
	# area width = room_size * 16 + (margin * 2) * 16
	check_zone.add_child(collisionShape2d)
	get_tree().root.add_child(check_zone)
	SceneSwitcher.on_map_close_functions.append(check_zone.queue_free)
	collisionShape2d.shape.size.x = (in_room.bottom_right.x - in_room.top_left.x) * 16 + (4 * 16)
	collisionShape2d.shape.size.y = (in_room.bottom_right.y - in_room.top_left.y) * 16 + (4 * 16)
	collisionShape2d.global_position = Vector2(in_room.center_position * Vector2i(16,16) + Vector2i(8,8))
	check_zone.body_entered.connect(entered_check_zone)
	
func entered_check_zone(body: Node2D) -> void:
	if !spawnpoint_already_triggered:
		if body.is_in_group("player_character"):
			spawnpoint_already_triggered = true
			player_in_treshhold.emit(self)

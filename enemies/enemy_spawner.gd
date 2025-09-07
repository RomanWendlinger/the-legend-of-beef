extends Node
class_name EnemySpawner


@export_group("trash mobs waves")
@export var enemy_tscn_files :Array[PackedScene]
@export var enemy_numbers := 1
@export var enemy_number_max_deviation := 3
@export_group("big bois")
@export var big_boi_files : Array[PackedScene]
## this is 0 indexed as always, so at 10 rooms the last room is 9
@export var big_boi_room_numbers : Array[int]

var enemy_spawners: Array[Node]

var rng : RandomNumberGenerator
var let_the_dogs_out := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rng = RandomNumberGenerator.new()
	SignalBus.players_spawned.connect(enable_enemy_spawning)
	SceneSwitcher.on_map_close_functions.append(clear_scene)
	
	SignalBus.final_boss_defeated.connect(final_boss_defeated)
	
	# get preexisting spawners
	enemy_spawners = get_tree().get_nodes_in_group("enemy_spawn_point")

	
func spawn_enemy(spawner: EnemySpawnPoint) -> void:
	if(!let_the_dogs_out):
		return
	if spawner.in_room.room_number in big_boi_room_numbers:
		spawn_big_boi(spawner)
	else:
		var scaled_enemy_number = ScalingManager.scale_enemy_spawn_numbers(enemy_numbers)
		var enemy_number_in_wave = randi_range(0, enemy_number_max_deviation) + scaled_enemy_number
		for i in enemy_number_in_wave:
			var enemyPackedScene = enemy_tscn_files.pick_random()
			var enemyNode = enemyPackedScene.instantiate()
			enemyNode = ScalingManager.scale_enemy(enemyNode)
			var spawnPosition = spawner.global_position + Vector2(randf_range(-20, 20),randf_range(-20, 20 ))
			_put_enemy_on_map(enemyNode, spawnPosition)
	
func clear_scene() -> void:
	get_tree().call_group("enemy_character", "queue_free")
	
func create_spawner(room: Room) -> void:
	var spawner = EnemySpawnPoint.new()
	spawner.melee_spawnpoint = true
	spawner.flying_spawnpoint = true
	spawner.position = room.center_position * 16
	spawner.in_room = room
	spawner.add_to_group("enemy_spawn_point")
	
	get_tree().root.add_child(spawner)
	enemy_spawners.append(spawner)
	
func enable_enemy_spawning() -> void:
	let_the_dogs_out = true
	for spawner : EnemySpawnPoint in enemy_spawners:
		spawner.spawnpoint_already_triggered = false
		spawner.player_in_treshhold.connect(spawn_enemy)

func spawn_big_boi(spawner) -> void:
	var enemyPackedScene = big_boi_files.pick_random()
	var enemyNode : Enemy = enemyPackedScene.instantiate()
	var spawnPosition = spawner.global_position
	enemyNode = ScalingManager.scale_enemy(enemyNode)
	enemyNode.is_final_boss = true
	_put_enemy_on_map(enemyNode, spawnPosition)
	

func _put_enemy_on_map(enemyNode: Node2D, position: Vector2) -> void:
	var spawnPosition = position
	enemyNode.set_global_position(spawnPosition)
	enemyNode.add_to_group("enemy_character")
	get_tree().root.get_node("Main").call_deferred("add_child", enemyNode)
	
func final_boss_defeated(position: Vector2) -> void:
	SignalBus.create_level_end_hole.emit(position)
	pass

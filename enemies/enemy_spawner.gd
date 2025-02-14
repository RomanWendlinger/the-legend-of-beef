extends Node

@export_group("Enemy Settings")
@export var respawn_timer := 2.0
@export var enemy_tscn_files :Array[PackedScene]
var remaining_respawn_time = 0.4
var rng : RandomNumberGenerator




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rng = RandomNumberGenerator.new()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#substract time delta aka count down
	remaining_respawn_time -= delta
	#if we hit 0
	if remaining_respawn_time < 0:
		remaining_respawn_time = respawn_timer
		spawn_enemy_tscn()
		
	
func spawn_enemy_tscn() -> void:
	print("Spawning enemy tscn")
	#get the enemies dir and pick a random one
	var enemyPackedScene = enemy_tscn_files.pick_random();
	var enemyNode:RigidBody2D = enemyPackedScene.instantiate();
	var spawnPosition = Vector2.ZERO
	spawnPosition.x = 600;
	spawnPosition.y = 600
	enemyNode.set_global_position(spawnPosition)
	enemyNode.add_to_group("enemy_character")
	get_tree().root.add_child(enemyNode)

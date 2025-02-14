extends RigidBody2D
@export_group("Movement")
@export var speed := 5.0
@export var target_dir := Vector2.ZERO
@export var state_pushed_back := false
@export var max_pushback_speed := 90

@export_group("Damage")
@export var damage := 5.0

var targeted_player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	getNearestPlayer()
	pass # Replace with function body.


func _physics_process(delta: float) -> void:
	var target_dir = global_position.direction_to(targeted_player.global_position)
	target_dir.normalized()
	var dist = global_position.distance_to(targeted_player.global_position)
	apply_impulse(target_dir * speed * delta * dist/2)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func getNearestPlayer():
	var player_characters = get_tree().get_nodes_in_group("player_character")
	if not player_characters.is_empty(): 
		print(player_characters)
		var closestPlayer = player_characters.reduce(returnClosestLocation)
		targeted_player = closestPlayer
		print("closest player: ", closestPlayer.get_global_position())
	

func returnClosestLocation(bestFetch: Area2D, newContender: Area2D):
	print("monster position: ", get_global_position(), "player new position: ", newContender.get_global_position(), "player bestFetch position: ", bestFetch.get_global_position())
	return bestFetch


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		body.take_damage(damage)
		body.push_back(global_position.direction_to(body.global_position).normalized() * (linear_velocity.length() / mass ))
	
		explode()
	pass # Replace with function body.

func explode() -> void:
	print("KABOOM")
	queue_free()
	visible = false
	set_process(false)
	pass

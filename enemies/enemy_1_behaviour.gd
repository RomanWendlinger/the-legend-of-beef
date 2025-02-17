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
	var recheck_timer = Timer.new()
	recheck_timer.timeout.connect(getNearestPlayer)
	get_tree().root.add_child(recheck_timer)
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
	print("players: ", player_characters.size())
	if not player_characters.is_empty(): 
		var closestPlayer = player_characters.reduce(returnClosestLocation)
		targeted_player = closestPlayer
	

func returnClosestLocation(bestFetch: Player, newContender: Player):
	if global_position.distance_to(bestFetch.global_position) < global_position.distance_to(newContender.global_position):
		return bestFetch
	return newContender


func _on_body_entered(body: Node) -> void:
	if body is Player:
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

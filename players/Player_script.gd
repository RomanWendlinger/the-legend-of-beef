extends CharacterBody2D

class_name Player

signal health_update
signal player_died
signal player_revived

@export_group("Survival")
@export var health := 100.0
@export var max_health := 140.0
@export var is_dead := false
@export var is_frozen := true

@export_group("Movement")
@export var speed := 100.0
@export var pushback_strength := 80.0
@export var is_pushed_back := false
@export var pushback_dampening := 0.4
@export var pushback_recover_speed := 3

var player_number : int
var shadowNode: Sprite2D
var spriteNode: Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shadowNode = get_node("Shadow")
	spriteNode = get_node("Character")
	pass # Replace with function body.
	
func _input(event: InputEvent) -> void:
	pass

	
func _physics_process(delta: float) -> void:
	var direction =Input.get_vector("P"+str(player_number)+" stick left","P"+str(player_number)+" stick right", "P"+str(player_number)+" stick up", "P"+str(player_number)+" stick down");
	direction.normalized()
	#if pushback is belov recovery speed (knockback speed), give back control
	if velocity.length() < pushback_recover_speed:
		is_pushed_back = false
	if is_pushed_back:
		velocity /= (1.0 + (pushback_dampening))
		velocity.x = clamp(velocity.x, -speed *2.0, speed *2.0)
		velocity.y = clamp(velocity.y, -speed *2.0, speed *2.0)
	if not is_pushed_back:
		if not (is_dead or is_frozen):
			velocity = direction * speed * delta
		else:
			velocity = direction * 0 * delta
		
	var contact = move_and_collide(velocity)
	if contact:
		var collider =  contact.get_collider()
		if collider is RigidBody2D:
			collider.constant_force = Vector2.ZERO
			collider.apply_impulse(global_position.direction_to(collider.global_position) * pushback_strength)
		else:
			pass
			
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_dead:
		spriteNode.rotation = 90.0
		spriteNode.flip_h = false
	if is_dead == false:
		spriteNode.rotation = 0
		if velocity.x > 0 :
			shadowNode.flip_h = true
			spriteNode.flip_h = true
		if velocity.x < 0:
			shadowNode.flip_h = false
			spriteNode.flip_h = false
	

func take_damage(damage: float) -> void:
	# cant kill whats already dead
	if not is_dead:
		health = clamp(health - damage, 0, max_health)
		health_update.emit()
		
		if health <= 0:
			health = 0
			is_dead = true
			player_died.emit()

	
func push_back(direction: Vector2) -> void:
	is_pushed_back = true
	velocity += direction
	

func _on_collision(body: Node) -> void:
	print("collision")
	pass # Replace with function body.

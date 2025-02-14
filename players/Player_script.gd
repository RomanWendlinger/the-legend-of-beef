extends CharacterBody2D

@export_group("Survival")
@export var health := 100.0

@export_group("Movement")
@export var speed := 100.0
@export var pushback_strength := 80.0
@export var is_pushed_back := false
@export var pushback_dampening := 0.4
@export var pushback_recover_speed := 3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _input(event: InputEvent) -> void:
	if event is InputEventAction:
		print("Action event: ", event.strength, event.action, event.pressed)

	
func _physics_process(delta: float) -> void:
	var direction =Input.get_vector("P1 stick left","P1 stick right", "P1 stick up", "P1 stick down");
	direction.normalized()
	#if pushback is belov recovery speed (knockback speed), give back control
	if velocity.length() < pushback_recover_speed:
		is_pushed_back = false
	if is_pushed_back:
		velocity /= (1.0 + (pushback_dampening))
		velocity.x = clamp(velocity.x, -speed *2.0, speed *2.0)
		velocity.y = clamp(velocity.y, -speed *2.0, speed *2.0)
	if not is_pushed_back:
		velocity = direction * speed * delta
		
	var contact = move_and_collide(velocity)
	if contact:
		print("contact")
		var collider =  contact.get_collider()
		print(collider)
		if collider is RigidBody2D:
			print("is rigid body")
			collider.constant_force = Vector2.ZERO
			collider.apply_impulse(global_position.direction_to(collider.global_position) * pushback_strength)
		else:
			pass
			
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func take_damage(damage: float) -> void:
	health -= damage
	
func push_back(direction: Vector2) -> void:
	is_pushed_back = true
	velocity += direction
	

func _on_collision(body: Node) -> void:
	print("collision")
	pass # Replace with function body.

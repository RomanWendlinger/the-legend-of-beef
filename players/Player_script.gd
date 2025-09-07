extends CharacterBody2D

class_name Player

enum States {IDLE, AIMING, FROZEN, DEAD}
var state: States = States.IDLE


@warning_ignore("unused_signal")
signal player_revived

@export var is_frozen := true

@export_group("Movement")
@export var speed := 100.0
@export var pushback_strength := 80.0
@export var is_pushed_back := false
@export var pushback_dampening := 0.4
@export var pushback_recover_speed := 3
@export var looking_at_vector := Vector2.ZERO

@export_group("Weapon")
@export var current_weapon: WeaponData
## percentage of the damage the weapon deals
@export var current_weapon_damage_scale := 100.0
@export_group("Misc")
@export var coin_count := 0

var player_number : int
var shadowNode: Sprite2D
var spriteNode: Sprite2D
var healthNode: HealthComponent
var interactable_stack: Array[Interactable]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shadowNode = get_node("Shadow")
	spriteNode = get_node("Character")
	healthNode = get_node("HealthComponent")
	SignalBus.freeze_game_time.connect(on_freeze_game_time)
	SceneSwitcher.on_map_close_functions.append(hide_player_from_map)
	SignalBus.start_pregame.connect(on_pregame)
	SignalBus.start_ingame.connect(on_ingame)
	if healthNode != null:
		healthNode.health_update.connect(health_update)
		healthNode.entity_died.connect(player_died)

func on_pregame() -> void:
	print("pre game!")
	
func on_ingame() -> void:
	health_update(healthNode.health, healthNode.max_health)
	SignalBus.player_coin_update.emit(player_number, coin_count)

func health_update(health: float, max_health: float) -> void:
	SignalBus.player_health_update.emit(player_number, health, max_health)
	
func player_died() -> void:
	state = States.DEAD
	SignalBus.player_died.emit(player_number)
	
func _physics_process(delta: float) -> void:
	var direction =Input.get_vector("P"+str(player_number)+" stick left","P"+str(player_number)+" stick right", "P"+str(player_number)+" stick up", "P"+str(player_number)+" stick down");
	direction.normalized()
	if direction != Vector2.ZERO:
		looking_at_vector = direction
	#if pushback is belov recovery speed (knockback speed), give back control
	if velocity.length() < pushback_recover_speed:
		is_pushed_back = false
	if is_pushed_back:
		velocity /= (1.0 + (pushback_dampening))
		velocity.x = clamp(velocity.x, -speed *2.0, speed *2.0)
		velocity.y = clamp(velocity.y, -speed *2.0, speed *2.0)
	if not is_pushed_back:
		#dead, frozen or just aiming
		if state not in [States.FROZEN, States.DEAD]:
			velocity = direction * speed * delta
			if state == States.AIMING and Input.is_action_pressed("P"+str(player_number)+" button 2"):
				velocity = Vector2.ZERO
		if state in [States.FROZEN, States.DEAD]:
			velocity = Vector2.ZERO
	move_player(velocity)
	
	if state == States.IDLE:
		if Input.is_action_just_pressed("P"+str(player_number)+" button 2"):
			if interactable_stack.size() > 0:
				interact_with_stack()
			else:
				state = States.AIMING
				start_aim(looking_at_vector)
	else:
		if state == States.AIMING:
			if Input.is_action_pressed("P"+str(player_number)+" button 2"):
				#respect deadzone
				if(direction.length_squared() > 0.1):
					aim(looking_at_vector, delta)
				pass
			if Input.is_action_just_released("P"+str(player_number)+" button 2"):
				state = States.IDLE
				if(direction.length_squared() > 0.1):	
					attack(looking_at_vector)
					return
				attack(Vector2.ZERO)
			
	
func move_player(velo, test = true) -> bool:
	var contact = move_and_collide(velo, test)
	if contact:
		var collider =  contact.get_collider()
		if collider is RigidBody2D:
			collider.constant_force = Vector2.ZERO
			collider.apply_impulse(global_position.direction_to(collider.global_position) * pushback_strength)
			return true
		if collider is TileMapLayer:
			#if we have a 0.0 velocity, return false
			if(velo.x == 0.0 and velo.y == 0.0):
				return false
			#try going horizontally
			if(velo.y != 0.0 and move_player(Vector2(velo.x, 0.0))):
				#try going vertically
				if(velo.x != 0.0 and !move_player(Vector2(0.0, velo.y))):
					return false
	move_and_collide(velo)
	return true
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if healthNode.is_dead:
		spriteNode.rotation = 90.0
		spriteNode.flip_h = false
	if healthNode.is_dead == false:
		spriteNode.rotation = 0
		if velocity.x > 0 :
			shadowNode.flip_h = true
			spriteNode.flip_h = true
		if velocity.x < 0:
			shadowNode.flip_h = false
			spriteNode.flip_h = false
	

	
func push_back(direction: Vector2) -> void:
	is_pushed_back = true
	velocity += direction
	
func start_aim(direction: Vector2) -> void:
	current_weapon.set_parent(self)
	current_weapon.start_aim(direction)
	pass
	
func aim(direction: Vector2, delta: float) -> void:
	current_weapon.aim(direction, delta)
	pass
	 
func attack(direction: Vector2) -> void:
	current_weapon.attack(direction)
	
func freeze() -> void:
	state = States.FROZEN
	is_frozen = true
	
func on_freeze_game_time(value) -> void:
	if value:
		state = States.FROZEN
	else:
		state = States.IDLE
	is_frozen = value

func add_interactable(elem: Interactable) -> void:
	interactable_stack.append(elem)
	
func remove_interactable(elem: Interactable) -> void:
	interactable_stack.remove_at(interactable_stack.find(elem))
	
func interact_with_stack() -> void:
	if interactable_stack.size() > 0:
		interactable_stack[0].interact(self)
		
func hide_player_from_map() -> void:
	visible = false
	is_frozen = true

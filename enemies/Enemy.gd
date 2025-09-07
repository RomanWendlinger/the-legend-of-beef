extends RigidBody2D
class_name Enemy
@export_group("Movement")
@export var speed := 5.0
@export var max_speed := 150
@export var target_dir := Vector2.ZERO
@export var state_pushed_back := false
@export var max_pushback_speed := 90
@export var flying := false

@export_group("Health")
@export var max_health := 150.0
@export var health := 150.0

@export_group("Damage")
@export var damage := 5.0

@export_group("Money")
@export var moneyValue := 1

@export var is_final_boss := false

var targeted_player

var shadowNode: Sprite2D
var monsterNode: Sprite2D
@onready var health_bar: HealthBar = $ui/HealthBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	SignalBus.freeze_game_time.connect(on_freeze_game_time)
	
	shadowNode = get_node("shadow")
	monsterNode = get_node("monster")
	getNearestPlayer()
	var recheck_timer = Timer.new()
	recheck_timer.timeout.connect(getNearestPlayer)
	get_tree().root.get_node("Main").add_child(recheck_timer)
	


func _physics_process(delta: float) -> void:
	target_dir = global_position.direction_to(targeted_player.global_position)
	target_dir.normalized()
	var dist = global_position.distance_to(targeted_player.global_position)
	if(freeze):
		linear_velocity = Vector2.ZERO
		return
	if linear_velocity.length() < max_speed: 
		# acceleration modifier
		var acceleration_modifier = dist/2
		# faster bosses
		if is_final_boss:
			acceleration_modifier = dist
			
		apply_impulse(target_dir * speed * delta * acceleration_modifier)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if linear_velocity.x > 0 :
		shadowNode.flip_h = true
		monsterNode.flip_h = true
	else:
		shadowNode.flip_h = false
		monsterNode.flip_h = false
	
func getNearestPlayer():
	var player_characters = get_tree().get_nodes_in_group("player_character")
	if not player_characters.is_empty(): 
		var closestPlayer = player_characters.reduce(returnClosestLocation)
		targeted_player = closestPlayer
	

func returnClosestLocation(bestFetch: Player, newContender: Player):
	if global_position.distance_to(bestFetch.global_position) < global_position.distance_to(newContender.global_position):
		return bestFetch
	return newContender


func _on_body_entered(body: Node) -> void:
	if body is Player:
		body.healthNode.take_damage(damage, global_position)
		body.push_back(global_position.direction_to(body.global_position).normalized() * (linear_velocity.length() / mass ))
		if not is_final_boss:
			explode()
	
func take_damage(dmg, impact_position: Vector2) -> void:
	health -= dmg
	print ("taking %s damage, new life %s" % [dmg, health])
	health_bar.max_health = max_health
	health_bar.current_health = health
	# make final boss faster on lower health
	if health / max_health > 5:
		max_speed = 300
	if (health <= 0):
		explode();
	else:
		#take knockback
		if is_final_boss:
			return
		push_back(impact_position.direction_to(global_position).normalized() * 100)
	

func explode() -> void:
	SignalBus.enemy_defeated.emit(self)
	if is_final_boss:
		SignalBus.final_boss_defeated.emit(global_position)
	queue_free()
	visible = false
	set_process(false)
	pass

func on_freeze_game_time(value: bool) -> void:
	freeze = value
func push_back(direction: Vector2) -> void:
	linear_velocity =direction 

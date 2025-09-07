extends Node
class_name HealthComponent

signal health_update
signal entity_died

@export var health := 100.0
@export var max_health := 140.0
@export var is_dead := false

func heal(heal: float) -> void:
	health = clamp(health + heal, 0, max_health)
	health_update.emit(health, max_health)
	
func take_damage(damage: float, _impact_position: Vector2) -> void:
	# cant kill whats already dead
	if not is_dead:
		health = clamp(health - damage, 0, max_health)
		health_update.emit(health, max_health)
		
		if health <= 0:
			#player
			#state = States.DEAD
			health = 0
			is_dead = true
			entity_died.emit()

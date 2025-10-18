extends StaticBody2D
class_name DestructibleCrate

@onready var health_component: HealthComponent = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
@export var coin_scene: PackedScene = preload("res://items/pickups/coin/coin.tscn")
@export var coins_to_drop := 1

func _ready() -> void:
	health_component.entity_died.connect(_on_destroyed)
	# Add to a group so it can be hit by weapons
	add_to_group("damageable")

# Forward damage to the health component
func take_damage(damage: float, impact_position: Vector2) -> void:
	health_component.take_damage(damage, impact_position)

func _on_destroyed() -> void:
	# Spawn coins
	for i in coins_to_drop:
		var coin = coin_scene.instantiate()
		# Offset coins slightly so they don't all overlap
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		coin.global_position = global_position + offset
		get_parent().add_child(coin)

	# Destroy the crate
	queue_free()

extends Area2D
class_name Pickupable_Component

enum PickupProperty {
	HEALTH = 1,
	MAX_HEALTH = 2,
	MAX_SPEED = 3,
	COIN_COUNT = 4,
	DAMAGE_PERCENTAGE = 5
}
@export var property : PickupProperty
@export var property_value := 0.0

@export var on_collection_remove_target : Node2D

var is_collected := false

func collect_item(body: Node2D) -> void:
	if not is_collected:
		is_collected = true
		SignalBus.pickup_collected.emit(body, self)
		if not on_collection_remove_target.is_queued_for_deletion():
			on_collection_remove_target.queue_free()

func _on_body_entered(body: Node2D) -> void:
	collect_item(body)

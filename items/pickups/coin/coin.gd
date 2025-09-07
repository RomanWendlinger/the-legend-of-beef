extends Node2D
class_name Coin

@onready var area_2d: Area2D = $Area2D
@export var coin_value := 1
var is_collected := false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_character"):
		#check for double collision on frame
		if not is_collected:
			is_collected = true
			SignalBus.coin_collected.emit(body, coin_value)
			queue_free()

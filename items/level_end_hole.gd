extends Node2D
class_name LevelEndHole

@export var target_map := "res://level/map1.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_character"):
		body.freeze()
		SceneSwitcher.requested_scene = target_map
		PlayerManager.player_finished_level(body)
		#SceneSwitcher.switch_scene(target_map)

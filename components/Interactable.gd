extends Area2D
class_name Interactable

func _on_body_entered(player: Player) -> void:
	if player is Player:
		player.add_interactable(self)
		
func _on_body_exited(player: Player) -> void:
	if player is Player:
		player.remove_interactable(self)

func interact(player: Player) -> void:
	pass

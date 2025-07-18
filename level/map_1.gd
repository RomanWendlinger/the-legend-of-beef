extends Node



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await PlayerManager.spawn_active_players()
	GuiManager.create_ingame_timer()
	for timer in get_tree().get_nodes_in_group("gui_ingame_timer"):
		timer = timer as IngameTimer
		timer.start()
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

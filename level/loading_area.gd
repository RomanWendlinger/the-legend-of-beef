extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.spawn_active_players()
	
	SignalBus.start_pregame.emit()
	#SceneSwitcher.switch_scene("res://level/map1.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#called from scene switcher?
func start_level() -> void:
	print("start level hub")
	await PlayerManager.spawn_active_players()
	SignalBus.start_ingame.emit()

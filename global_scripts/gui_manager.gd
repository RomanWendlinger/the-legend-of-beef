extends Node

var player_gui_node: CanvasLayer
var player1_health_bar: ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.players_spawned.connect(create_player_panels)
	pass # Replace with function body.

func create_player_panels() -> void:
	print("CREATING PLAYER PANELS")
	player_gui_node = load("res://gui_elements/player_gui.tscn").instantiate();
	get_tree().root.add_child(player_gui_node)
	player1_health_bar = player_gui_node.get_node("Player1Box/Player1HealthBar")
	print("p1healthbar: ", player1_health_bar)
	PlayerManager.player1_gui_update.connect(player1_gui_update)
	pass

func player1_gui_update() -> void:
	print("GUIManager: p1 gui update: ")
	player1_health_bar.max_value = PlayerManager.player1.max_health
	player1_health_bar.value = PlayerManager.player1.health
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

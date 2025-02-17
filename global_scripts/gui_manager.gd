extends Node

var player_gui_node: CanvasLayer
var player1_health_bar: ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.players_spawned.connect(create_player_panels)
	pass # Replace with function body.

func create_player_panels() -> void:
	player_gui_node = load("res://gui_elements/player_gui.tscn").instantiate();
	get_tree().root.add_child(player_gui_node)
	player1_health_bar = player_gui_node.get_node("Player1Box/Player1HealthBar")
	print("p1healthbar: ", player1_health_bar)
	print("wanted signal: ", PlayerManager.players_spawned)
	PlayerManager.gui_update.connect(player_gui_update)
	pass

func player_gui_update(player_number: int) -> void:
	print("player_number: ",player_number);
	player1_health_bar.max_value = PlayerManager.player_dict[str(player_number)].max_health
	player1_health_bar.value = PlayerManager.player_dict[str(player_number)].health
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Node

signal players_spawned
signal player1_gui_update
signal player2_gui_update
signal player3_gui_update
signal player4_gui_update

# max 4 players
# every player has a corner for their stats?
# Stats needed?
# create internal class?
# - Health
# - Weapons array
# - some timeouts ?
# - spawner function
# - state mask (dead/alive/tumble/invincible/rolling?)
# - is_active bool
# - Voting state
# 

 
var player1_active := false
var player1: Player
var player2_active := false
var player2: Player
var player3_active := false
var player3: Player
var player4_active := false
var player4: Player

var active_players : Array[Player]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	active_players = []
	
func set_player_active(playernumber: int, active: bool):
	if playernumber == 1:
		player1_active = active
		player1 = Player.new()
		player1.add_to_group("player_character");
	if playernumber == 2:
		player2_active = active
		player2 = Player.new()
		player2.add_to_group("player_character");
	if playernumber == 3:
		player3_active = active
	if playernumber == 4:
		player4_active = active
		
func get_player_refs() -> Array:
	var retArray = []
	if player1_active:
		retArray.append(player1)
	if player2_active:
		retArray.append(player2)
	if player3_active:
		retArray.append(player3)
	if player4_active:
		retArray.append(player4)
	return retArray
	
	
# SPAWN POINTS
# p1 x250y200
	
func spawn_active_players() -> void:
	var current_root = get_tree().root
	current_root
	if player1_active:
		var player1_node = load("res://players/player.tscn").instantiate()
		player1 = player1_node
		player1_node.global_position = Vector2(250, 200)
		player1_node.z_index = 1
		player1_node.player_number = 1
		player1.health_update.connect(func (): player1_gui_update.emit())
		current_root.add_child(player1_node)
	if player2_active:
		var player2_node = load("res://players/player.tscn").instantiate()
		player2 = player2_node
		player2_node.global_position = Vector2(400, 400)
		player2_node.z_index = 1
		player2_node.player_number = 2
		current_root.add_child(player2_node)
		
	players_spawned.emit()

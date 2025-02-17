extends Node

signal players_spawned

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
signal gui_update(player_number: int)
signal player_died(player_number: int)

var player_dict = {
	"1": Player,
	"2": Player,
	"3": Player,
	"4": Player,
}

# we store the int of active player positions
# [1, 3, 4] for example
var active_players : Array[int]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	active_players = []
	
func set_player_active(playernumber: int, active: bool):
	if not active_players.has(playernumber):
		active_players.append(playernumber)
	player_dict[str(playernumber)] = Player.new()
	player_dict[str(playernumber)].add_to_group("player_character");
		
func get_player_refs() -> Array:
	var retArray = []
	for player_number in active_players:
		retArray.append(player_dict[str(player_number)])
	return retArray
	
# SPAWN POINTS
# p1 x250y200
	
func spawn_active_players() -> void:
	for player_number in active_players:
		spawn_player(player_number)
		
	players_spawned.emit()
	

func spawn_player(player_number: int) -> void:
	var player_node = load("res://players/player.tscn").instantiate()
	player_node.global_position = get_spawn_position_for_player(player_number)
	player_node.z_index = 1
	player_node.player_number = player_number
	player_dict[str(player_number)] = player_node
	player_node.health_update.connect(func (): gui_update.emit(1))
	get_tree().root.add_child(player_node)
	
func get_spawn_position_for_player(player_number: int) -> Vector2:
	match player_number:
		1:
			return Vector2(400, 400)
		_:
			return Vector2(200, 200)

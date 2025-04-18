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
signal managed_player_died(player_number: int)
signal all_player_died

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
	#add player number to array for easier iterations
	if not active_players.has(playernumber):
		active_players.append(playernumber)
		
func get_player_refs() -> Array:
	var retArray = []
	for player_number in active_players:
		retArray.append(player_dict[str(player_number)])
	return retArray
	
# Spawns all the players one after 
func spawn_active_players() -> void:
	#spawn em in
	for player_number in active_players:
		await animate_spawn_players(player_number)
	#after animation, let em move
	for player_number in active_players:
		PlayerManager.player_dict[str(player_number)].is_frozen = false
	players_spawned.emit()
	
# spawn in and animate
func animate_spawn_players(player_number: int) -> void :
	#create character
	var player_node: Player = spawn_player(player_number);
	var anim_node:AnimationPlayer = player_node.get_node("AnimationPlayer")
	# play animation and wait until finished signal
	anim_node.play("spawning")
	await anim_node.animation_finished
	return 

#simply create the character
func spawn_player(player_number: int) -> Player:
	var player_node: Player = load("res://players/granny/player.tscn").instantiate()
	#every player has his own spawn area
	player_node.global_position = get_spawn_position_for_player(player_number)
	#set above background tile
	player_node.z_index = 1
	#let em know their position
	player_node.player_number = player_number
	#add created character to global dict for easier finding
	player_dict[str(player_number)] = player_node
	# SIGNALS
	#if player gets hit, let the gui also know
	player_node.health_update.connect(func (): gui_update.emit(player_number))
	player_node.player_died.connect(emit_player_died.bind(player_node))
	
	#add to tree 
	get_tree().root.add_child(player_node)
	return player_node
	
func emit_player_died(player_node): 
	managed_player_died.emit(player_node.player_number)
	if active_players.all(func(player_number: int): return player_dict[str(player_number)].is_dead) :
		print("all dead gg")
		all_player_died.emit()
	
	
func get_spawn_position_for_player(player_number: int) -> Vector2:
	match player_number:
		1:
			return Vector2(400, 400)
		2:
			return Vector2(450, 400)
		3: 
			return Vector2(500, 400)
		4: 
			return Vector2(550, 400)
		_:
			return Vector2(500, 350)

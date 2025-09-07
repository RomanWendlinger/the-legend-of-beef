extends Node

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


var player_dict = {
	"1": Player,
	"2": Player,
	"3": Player,
	"4": Player,
}

# we store the int of active player positions
# [1, 3, 4] for example
var active_players : Array[int]
var finished_players : Array[int]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	active_players = []
	SceneSwitcher.on_map_close_functions.append(clear_current_scene)
	if OS.is_debug_build():
		print("DEBUG BUILD")
		set_player_active(1, true)
	
func set_player_active(playernumber: int, _active: bool):
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
	SignalBus.players_spawned.emit()
	
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
	var player_node: Player
	# check if player already exists
	if player_dict[str(player_number)] is CharacterBody2D:
		player_node = player_dict[str(player_number)]
	else:
		match player_number:
			1:
				player_node = load("res://players/granny/granny.tscn").instantiate()
			2: 
				player_node = load("res://players/WZRD.tscn").instantiate()
	#every player has his own spawn area
	player_node.global_position = get_spawn_position_for_player(player_number)
	#set above background tile
	player_node.z_index = 1
	#let em know their position
	player_node.player_number = player_number
	
	player_node.visible = true
	player_node.is_frozen = false
	player_node.state = player_node.States.IDLE
	#add created character to global dict for easier finding
	player_dict[str(player_number)] = player_node
		#if player gets hit, let the gui also know
	
	#add to tree 
	get_tree().root.add_child(player_node)
	return player_node
	
func emit_player_died(player_node): 
	if active_players.all(func(player_number: int): return player_dict[str(player_number)].is_dead) :
		SignalBus.all_player_died.emit()
		return
	SignalBus.managed_player_died.emit(player_node.player_number)
	
	
func get_spawn_position_for_player(player_number: int) -> Vector2:
	var spawnPoints = get_tree().get_nodes_in_group("player_spawn_point")
	if spawnPoints.size() >= player_number:
		# zero based array vs 1 based player numbers
		return spawnPoints[player_number-1].global_position
	match player_number:
		1:
			return Vector2(200, 400)
		2:
			return Vector2(250, 400)
		3: 
			return Vector2(300, 400)
		4: 
			return Vector2(350, 400)
		_:
			return Vector2(400, 350)

func clear_current_scene() -> void:
	for playerint in active_players:
		player_dict[str(playerint)].hide_player_from_map()
	pass

func player_finished_level(player: Player ) -> void:
	finished_players.append(player.player_number)
	player.visible = false
	active_players.sort()
	finished_players.sort()
	if active_players == finished_players:
		SignalBus.players_level_completed.emit()
		finished_players = []

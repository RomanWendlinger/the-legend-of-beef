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


var player_dict: Dictionary = {
	"1": null,
	"2": null,
	"3": null,
	"4": null,
}

# we store the int of active player positions
# [1, 3, 4] for example
var active_players : Array[int]
var finished_players : Array[int]

# Per-slot selected weapon, set by player_select_screen before level start.
var _selected_weapons: Dictionary = { 1: null, 2: null, 3: null, 4: null }

# Per-slot selected character option, set by player_select_screen on confirm.
var _selected_characters: Dictionary = { 1: null, 2: null, 3: null, 4: null }


func set_selected_weapon(player_number: int, weapon: WeaponData) -> void:
	_selected_weapons[player_number] = weapon


func set_selected_character(player_number: int, option: CharacterOption) -> void:
	_selected_characters[player_number] = option

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	active_players = []
	SceneSwitcher.on_map_close_functions.append(clear_current_scene)
	SignalBus.player_died.connect(_on_player_died)
	if OS.is_debug_build():
		print("DEBUG BUILD")
		set_player_active(1, true)
	
func set_player_active(playernumber: int, active: bool):
	if active:
		if not active_players.has(playernumber):
			active_players.append(playernumber)
	else:
		active_players.erase(playernumber)
		
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
	var anim_node: AnimationPlayer = player_node.get_node_or_null("AnimationPlayer")
	if anim_node == null:
		return
	# play animation and wait until finished signal
	anim_node.play("spawning")
	await anim_node.animation_finished
	return

#simply create the character
func spawn_player(player_number: int) -> Player:
	var player_node: Player
	# check if player already exists
	var existing = player_dict[str(player_number)]
	if is_instance_valid(existing) and existing is CharacterBody2D:
		player_node = existing
	else:
		var auth_manager: Node = get_node("/root/AuthManager")
		if auth_manager.is_authenticated(player_number):
			player_node = _spawn_bluesky_player(player_number, auth_manager)
		else:
			var option: CharacterOption = _selected_characters.get(player_number, null)
			if option == null:
				option = load("res://players/options/granny.tres")
			player_node = load(option.scene_path).instantiate()
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

	# Apply the weapon selected on the player-select screen, if any.
	var chosen_weapon: WeaponData = _selected_weapons.get(player_number, null)
	if chosen_weapon != null:
		player_node.current_weapon = chosen_weapon

	# Duplicate the WeaponData so each player has independent per-shot state
	# (parent_node, anim) — sharing the same .tres causes cross-player clobbering.
	if player_node.current_weapon != null:
		player_node.current_weapon = player_node.current_weapon.duplicate()

	#add to tree
	get_tree().root.add_child(player_node)
	return player_node


func _spawn_bluesky_player(player_number: int, auth_manager: Node) -> Player:
	var node: Player = load("res://players/bluesky_player.tscn").instantiate()

	# Apply cached stat budget
	var budget: StatBudget = auth_manager.get_stat_budget(player_number)
	if budget == null:
		budget = StatBudget.new()
	node.stat_budget = budget

	# Build and assign sprite frames
	var png_bytes: PackedByteArray = auth_manager.get_sprite_png(player_number)
	var sf: SpriteFrames = SpriteSlicer.build_frames_from_png(png_bytes)
	if sf == null:
		sf = _fallback_sprite_frames()
	node.set_sprite_frames(sf)

	return node


func _fallback_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var rogues_tex: Texture2D = load("res://assets/sprites/rogues.png")
	var at := AtlasTexture.new()
	at.atlas = rogues_tex
	at.region = Rect2(96, 192, 32, 32)
	sf.add_animation(&"idle_down")
	sf.set_animation_loop(&"idle_down", false)
	sf.set_animation_speed(&"idle_down", 1.0)
	sf.add_frame(&"idle_down", at)
	# Alias the remaining animations to the same single frame so _play_if_not_current never errors
	for anim: StringName in [&"idle_left", &"idle_right", &"idle_up",
			&"walk_down", &"walk_left", &"walk_right", &"walk_up"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, false)
		sf.set_animation_speed(anim, 1.0)
		sf.add_frame(anim, at)
	return sf
	
func _on_player_died(player_number: int) -> void:
	# Check if all players are dead
	if active_players.all(_is_player_slot_dead):
		SignalBus.all_player_died.emit()
		return
	# Otherwise trigger beer time for this specific player
	SignalBus.managed_player_died.emit(player_number)

func _is_player_slot_dead(p_num: int) -> bool:
	var p = player_dict[str(p_num)]
	if not is_instance_valid(p) or p.healthNode == null:
		return true
	return p.healthNode.is_dead

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

extends Node

var player_gui_node: CanvasLayer
var timer_gui_node: IngameTimer
var gameover_gui_node: CanvasLayer
var ingame_timer: Timer
var health_bar = {
	"1": ProgressBar,
	"2": ProgressBar,
	"3": ProgressBar,
	"4": ProgressBar,
}

const BEER_TIME = preload("res://gui_elements/beertime/BeerTime.tscn")
var beer_time_gui_element: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.players_spawned.connect(create_player_panels)
	SignalBus.all_player_died.connect(create_game_over_panels)
	SignalBus.managed_player_died.connect(start_beer_time)
	SignalBus.scene_transition.connect(scene_transition)
	SceneSwitcher.on_map_close_functions.append(clear_current_gui)
	SignalBus.players_level_completed.connect(show_level_finished_overlay)
	SignalBus.gui_update.connect(player_gui_update)
	SignalBus.player_health_update.connect(player_health_update)
	
	
# add players gui and show for active players
# connect signals
func create_player_panels() -> void:
	player_gui_node = load("res://gui_elements/player_gui.tscn").instantiate();
	
	get_tree().root.get_node("Main").add_child(player_gui_node)
	var gui_player_health_nodes = get_tree().get_nodes_in_group("gui_player_health")
	var gui_player_box_nodes = get_tree().get_nodes_in_group("gui_player_box")
	for active_player in PlayerManager.active_players:
		#register health elem
		health_bar[str(active_player)] = gui_player_health_nodes.filter(func (el: Node): return el.name == "Player"+str(active_player)+"HealthBar")[0]
		#display players gui box
		var gui_box: Control = gui_player_box_nodes.filter(func (el: Node): return el.name == "Player"+str(active_player)+"Box")[0]
		gui_box.visible = true
	# connect player events to gui events
	# update init values to the gui for active players
	for active_player in PlayerManager.active_players:
		player_gui_update(active_player)

# fetch values from signal player and update the gui
# currently updating
# - max_health
# - health
func player_gui_update(player_number: int) -> void:
	health_bar[str(player_number)].max_value = PlayerManager.player_dict[str(player_number)].healthNode.max_health
	health_bar[str(player_number)].value = PlayerManager.player_dict[str(player_number)].healthNode.health
	
func player_health_update(player_number: int, current_health: float, max_health: float) -> void:
	health_bar[str(player_number)].value = current_health
	health_bar[str(player_number)].max_value = max_health
	
func create_ingame_timer() -> void:
	timer_gui_node = load("res://gui_elements/ingame_timer.tscn").instantiate()
	get_tree().root.get_node("Main").add_child(timer_gui_node)
	
func start_ingame_timer() -> void:
	timer_gui_node.start()
	
func create_game_over_panels() -> void:
	gameover_gui_node = load("res://gui_elements/gameover.tscn").instantiate()
	get_tree().root.get_node("Main").add_child(gameover_gui_node)
	var end_screen_timer = Timer.new()
	end_screen_timer.one_shot = true
	end_screen_timer.wait_time = 5.0
	end_screen_timer.autostart = true
	end_screen_timer.timeout.connect(scene_switch_main_menu)
	add_child(end_screen_timer)
	
func scene_switch_main_menu() -> void:
	SignalBus.start_map_close.emit()
	SceneSwitcher.switch_scene("res://gui_elements/main_menu.tscn")
	
func clear_current_gui() -> void:
	player_gui_node.queue_free()
	if gameover_gui_node:
		gameover_gui_node.queue_free()
	timer_gui_node.queue_free()
	
func start_beer_time(_player_number: int) -> void:
	print("BEER TIME")
	beer_time_gui_element = BEER_TIME.instantiate()
	SignalBus.freeze_game_time.emit(true)
	get_tree().root.get_node("Main").add_child(beer_time_gui_element)
	beer_time_gui_element.play_start_animation()
		
func scene_transition(status) -> void:
	if status == "START":
		print("STARTED")
	if status == "FINISHED":
		print("FINISHED")
		
func show_level_finished_overlay() -> void:
	player_gui_node.visible = false
	if timer_gui_node:
		timer_gui_node.pause()
	var transition_timer = Timer.new()
	transition_timer.one_shot = true
	transition_timer.wait_time = 1
	transition_timer.timeout.connect(SignalBus.start_map_close.emit)
	get_tree().root.get_node("Main").add_child(transition_timer)
	transition_timer.start()

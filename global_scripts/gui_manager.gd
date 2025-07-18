extends Node

signal map_scene_ended

var player_gui_node: CanvasLayer
var timer_gui_node: CanvasLayer
var gameover_gui_node: CanvasLayer
var ingame_timer: Timer
var health_bar = {
	"1": ProgressBar,
	"2": ProgressBar,
	"3": ProgressBar,
	"4": ProgressBar,
	
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.players_spawned.connect(create_player_panels)
	PlayerManager.all_player_died.connect(create_game_over_panels)
	pass # Replace with function body.
	
# add players gui and show for active players
# connect signals
func create_player_panels() -> void:
	player_gui_node = load("res://gui_elements/player_gui.tscn").instantiate();
	
	get_tree().root.add_child(player_gui_node)
	var gui_player_health_nodes = get_tree().get_nodes_in_group("gui_player_health")
	var gui_player_box_nodes = get_tree().get_nodes_in_group("gui_player_box")
	for active_player in PlayerManager.active_players:
		#register health elem
		health_bar[str(active_player)] = gui_player_health_nodes.filter(func (el: Node): return el.name == "Player"+str(active_player)+"HealthBar")[0]
		#display players gui box
		var gui_box: Control = gui_player_box_nodes.filter(func (el: Node): return el.name == "Player"+str(active_player)+"Box")[0]
		gui_box.visible = true
	# connect player events to gui events
	PlayerManager.gui_update.connect(player_gui_update)
	# update init values to the gui for active players
	for active_player in PlayerManager.active_players:
		player_gui_update(active_player)

# fetch values from signal player and update the gui
# currently updating
# - max_health
# - health
func player_gui_update(player_number: int) -> void:
	health_bar[str(player_number)].max_value = PlayerManager.player_dict[str(player_number)].max_health
	health_bar[str(player_number)].value = PlayerManager.player_dict[str(player_number)].health
	
func create_ingame_timer() -> void:
	timer_gui_node = load("res://gui_elements/ingame_timer.tscn").instantiate()
	get_tree().root.add_child(timer_gui_node)
	
func start_ingame_timer() -> void:
	timer_gui_node.start
	
func create_game_over_panels() -> void:
	gameover_gui_node = load("res://gui_elements/gameover.tscn").instantiate()
	get_tree().root.add_child(gameover_gui_node)
	var end_screen_timer = Timer.new()
	end_screen_timer.one_shot = true
	end_screen_timer.wait_time = 5.0
	end_screen_timer.autostart = true
	end_screen_timer.timeout.connect(scene_switch_main_menu)
	add_child(end_screen_timer)
	
func scene_switch_main_menu() -> void:
	map_scene_ended.emit()
	clear_current_gui()
	SceneSwitcher.switch_scene("res://gui_elements/main_menu.tscn")
	
func clear_current_gui() -> void:
	player_gui_node.queue_free()
	gameover_gui_node.queue_free()
	timer_gui_node.queue_free()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

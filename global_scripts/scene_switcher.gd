extends Node

var current_scene = null
var new_scene = null
var new_scene_packed: PackedScene
var requested_scene = ""
var scene_transition_in_progress = false
var loading_scene_path = "res://level/hub_area.tscn"

#execute all functions and then load the next function
var on_map_close_functions: Array[Callable] = []

func _ready() -> void:
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() -1 )
	SignalBus.start_map_close.connect(execute_map_close_callables)
	SceneSwitcher.on_map_close_functions.append(load_hub_scene)
	SignalBus.start_map_load.connect(switch_scene)
	
func execute_map_close_callables() -> void:
	for callable in on_map_close_functions:
		callable.call()
	on_map_close_functions = []
	SignalBus.start_map_load.emit()
	
	
func _process(delta: float) -> void:
	if(scene_transition_in_progress):
		
		var progress = []
		ResourceLoader.load_threaded_get_status(requested_scene, progress)
		if progress[0] == 1:
			SignalBus.scene_transition.emit("FINISHED")
			_deferred_switch_scene(requested_scene)
		
func switch_scene(res_path = null):
	if res_path != null:
		requested_scene = res_path
	scene_transition_in_progress = true
	ResourceLoader.load_threaded_request(requested_scene, "",false,0)

func _deferred_switch_scene(res_path):
	new_scene_packed = ResourceLoader.load_threaded_get(res_path)
	new_scene = new_scene_packed.instantiate()
	load_map_into_scene()

func load_map_into_scene() -> void:
	if is_instance_valid(current_scene):
		current_scene.free()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene = new_scene
	if current_scene.has_method("start_level"):
		current_scene.start_level()

func load_hub_scene() -> void:
	
	switch_scene(loading_scene_path)

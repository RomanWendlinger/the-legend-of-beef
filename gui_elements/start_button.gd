extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	grab_focus()
	pass # Replace with function body.

func _on_pressed() -> void:
	load_scene_with_loading_screen("res://gui_elements/player_select_screen.tscn")
	
func load_scene_with_loading_screen(path_to_scene: String):
	SceneSwitcher.switch_scene(path_to_scene)

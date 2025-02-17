extends Node

signal scene_loaded

@export var forced_delay: float = 0.5
@export var next_scene_path: String
var scene_load_status = 0
var progress = [0.0] # Initialize with a default value
var loaded_scene: PackedScene
@onready var progress_label: Label = $RichTextLabel/ProgressLabel
@onready var screenshot_bg: TextureRect = $ScreenshotBg
#@onready var tips_label: Label = $TipsLabel

@export var load_screen_tips:Array[String]

func _ready() -> void:
	#tips_label.text = load_screen_tips.pick_random()
	pass

func _process(delta: float) -> void:
	if next_scene_path == "":
		return # Do nothing if no scene has been set
		
	scene_load_status = ResourceLoader.load_threaded_get_status(next_scene_path, progress)
	var actual_progress = progress[0] * 100
	var rounded_progress = int(floor(actual_progress))
	
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		loaded_scene = ResourceLoader.load_threaded_get(next_scene_path)
		get_tree().change_scene_to_packed(loaded_scene)
		scene_loaded.emit()
		queue_free()
		
	elif scene_load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_label.text = str(rounded_progress) + "%"
		
func start_loading_scene(path: String):
	next_scene_path = path
	print("loading scene " + path)
	#if GameManager.savegame_screenshot:
	#    var texture = ImageTexture.create_from_image(GameManager.savegame_screenshot)
	#    if next_scene_path == "res://scenes/main_scene.tscn":
	#        screenshot_bg.texture = texture
	#    ## looks shit, keeps the menu over it
	### 6mb game file naw man
	
	ResourceLoader.load_threaded_request(next_scene_path)


func _on_scene_loaded() -> void:
	print("yes")
	pass # Replace with function body.

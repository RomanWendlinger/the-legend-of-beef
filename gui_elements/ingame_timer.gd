extends CanvasLayer
class_name IngameTimer

var time_elapsed := 0.0
var is_paused = true
@onready var timeLabel: Label = $HBoxContainer/Time

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.start_ingame.connect(start)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if(!is_paused):
		time_elapsed += delta
	var minutes = time_elapsed / 60
	var seconds = fmod(time_elapsed, 60)
	timeLabel.text = "%02d:%02d" % [minutes, seconds]
	
func pause() -> void:
	is_paused = true
	
func reset() -> void:
	time_elapsed = 0.0

func start() -> void:
	is_paused = false

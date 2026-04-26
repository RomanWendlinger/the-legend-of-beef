extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var player_number: int = 1
var animation_finished: bool = false

func _ready() -> void:
	# Wait for animation to finish before allowing input
	animation_player.animation_finished.connect(_on_animation_finished)
	
	
func play_start_animation() -> void:
	animation_player.play("start")

func set_player_number(p_number: int) -> void:
	player_number = p_number

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "start":
		SignalBus.beer_time_start_animation_finished.emit()

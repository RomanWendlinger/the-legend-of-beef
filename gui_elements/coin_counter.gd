extends Label
class_name coin_counter_label

@export var player_number := 1
@export var count := 0

func _ready() -> void:
	SignalBus.player_coin_update.connect(update_counter)
	
func update_counter(play_num: int, value: int) -> void:
	if play_num == player_number:
		text = str(value)

extends ProgressBar
class_name HealthBar

@export var max_health : float
@export var current_health : float
@export var assigned_player_number := 0
func _ready() -> void:
	self.visible = false
	SignalBus.player_health_update.connect(update_player_health)

func _process(_delta: float) -> void:
	value = current_health
	max_value = max_health
	# show bar only when damaged
	if(value == max_health):
		self.visible = false
	else:
		self.visible = true
func update_player_health(player_number: int, health: float, player_max_health: float) -> void:
	if player_number == assigned_player_number:
		current_health = health
		max_health = player_max_health

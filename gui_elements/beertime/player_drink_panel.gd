extends PanelContainer

@export var player_number: int
@onready var playerNumberLabel:Label = %PlayerLabel

@onready var beer_bottle: TextureProgressBar = %BeerBottle
@onready var beer_label: Label = %DrinkLabel


# Beer level settings
var MIN_BEER_LEVEL : int
var MAX_BEER_LEVEL : int
const BEER_STEP: float = 1.0  # Adjust beer level by 10g increments

var current_beer_level : int  

var input_enabled: bool = true

func _ready() -> void:
	playerNumberLabel.text = "Player "+str(player_number)
	MAX_BEER_LEVEL = BeerManager.current_beer_stat[str(player_number)].current_bottle_max_volume
	MIN_BEER_LEVEL = 0
	current_beer_level = BeerManager.current_beer_stat[str(player_number)].current_weight
	
	beer_bottle.max_value = MAX_BEER_LEVEL
	update_beer_display()
	
func _process(delta: float) -> void:
	if not input_enabled:
		return

	# Handle up/down input for beer level adjustment
	var input_up_action = "P" + str(player_number) + " stick up"
	var input_down_action = "P" + str(player_number) + " stick down"
	var confirm_action = "P" + str(player_number) + " button 2"

	# Adjust beer level with up/down stick
	if Input.is_action_pressed(input_up_action):
		increase_beer_level()
	elif Input.is_action_pressed(input_down_action):
		decrease_beer_level()

	# Confirm selection
	if Input.is_action_just_pressed(confirm_action):
		confirm_beer_level()
	
func increase_beer_level() -> void:
	current_beer_level = clampf(current_beer_level + BEER_STEP, MIN_BEER_LEVEL, MAX_BEER_LEVEL)
	update_beer_display()

func decrease_beer_level() -> void:
	current_beer_level = clampf(current_beer_level - BEER_STEP, MIN_BEER_LEVEL, MAX_BEER_LEVEL)
	update_beer_display()

func update_beer_display() -> void:
	beer_bottle.value = current_beer_level
	beer_label.text = str(int(current_beer_level)) + "g"

func confirm_beer_level() -> void:
	input_enabled = false
	print("Player ", player_number, " confirmed beer level: ", current_beer_level, "g")

	# TODO: Store beer level for player stats/effects
	# You can emit a signal here or call PlayerManager to store this data

	# Resume game
	resume_game()

func resume_game() -> void:
	# Unfreeze game
	SignalBus.freeze_game_time.emit(false)

	# Remove this overlay
	queue_free()

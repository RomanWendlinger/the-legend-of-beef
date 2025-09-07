extends Control

@export var hold_timer := 1.0

var timerArray: Array[Timer]
# Player stuff
var p1Label: Label
var p1PressLabel: Label
var p1ProgressBar: ProgressBar

var p2Label: Label
var p2PressLabel: Label
var p2ProgressBar: ProgressBar

var p3Label: Label
var p3PressLabel: Label
var p3ProgressBar: ProgressBar

var p4Label: Label
var p4PressLabel: Label
var p4ProgressBar: ProgressBar
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	p1Label = $VBoxContainer/row/col1/row1/VBoxContainer/Label1
	p1PressLabel = $VBoxContainer/row/col1/row1/VBoxContainer/PressLabel1
	p1ProgressBar = $VBoxContainer/row/col1/row1/VBoxContainer/ProgressBar1
	
	p2Label = $VBoxContainer/row/col2/row1/VBoxContainer/Label2
	p2PressLabel = $VBoxContainer/row/col2/row1/VBoxContainer/PressLabel2
	p2ProgressBar = $VBoxContainer/row/col2/row1/VBoxContainer/ProgressBar2
	
	p3Label = $VBoxContainer/row2/col1/row1/VBoxContainer/Label3
	p3PressLabel = $VBoxContainer/row2/col1/row1/VBoxContainer/PressLabel3
	p3ProgressBar = $VBoxContainer/row2/col1/row1/VBoxContainer/ProgressBar3
	
	p4Label = $VBoxContainer/row2/col2/row1/VBoxContainer/Label4
	p4PressLabel = $VBoxContainer/row2/col2/row1/VBoxContainer/PressLabel4
	p4ProgressBar = $VBoxContainer/row2/col2/row1/VBoxContainer/ProgressBar4
	
	timerArray.resize(5)

func _input(_event: InputEvent) -> void:
	#handle player 1 input
	manage_button_actions(1)
	
	#handle player 2 input
	manage_button_actions(2)
	
	#handle player 3 input
	#manage_button_actions(3)
	
	#handle player 4 input
	#manage_button_actions(4)

	
func player_ready(playerNumber: int) -> void:
	var press_label = get("p"+str(playerNumber)+"PressLabel")
	var text_label = get("p"+str(playerNumber)+"Label")
	press_label.text = "hold Button to start"
	text_label.text = "NOICE"
	PlayerManager.set_player_active(playerNumber, true)
	
func manage_button_actions(player_number: int) -> void:
	#handle player 1 input
	if Input.is_action_pressed("P"+str(player_number)+" button 1"):
		if PlayerManager.active_players.has(player_number):
			# hold to play mechanic
			#timer already running?
			if timerArray[player_number] and not timerArray[player_number].is_stopped():
				pass
			else:
				#start timer for level start
				timerArray[player_number] = Timer.new()
				get_tree().root.get_children()[0].add_child(timerArray[player_number])
				timerArray[player_number].process_callback = Timer.TIMER_PROCESS_IDLE
				timerArray[player_number].start(hold_timer)
				timerArray[player_number].one_shot = true
				timerArray[player_number].timeout.connect(start_next_level)
		else:
			#set it active
			player_ready(player_number)
	else:
		if PlayerManager.active_players.has(player_number):
			# hold to play mechanic
			# remove timer
			if timerArray[player_number]:
				timerArray[player_number].stop()
				p1ProgressBar.value = 0
	pass

func start_next_level() -> void:
	stop_bars()
	SceneSwitcher.switch_scene("res://level/map1.tscn")

func stop_bars() -> void:
	for timer in timerArray:
		if is_instance_valid(timer):
			timer.stop()
	pass

func _process(_delta: float) -> void:
	for timer in timerArray:
		if timer is Timer and not timer.is_stopped():
			var progress = (hold_timer - timer.time_left) / hold_timer * 100
			get("p"+str(timerArray.find(timer))+"ProgressBar").value = progress
		

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

func _input(event: InputEvent) -> void:
	#handle player 1 input
	manage_button_actions(1)

	
func player1_ready(playerNumber: int, press_label: Label, text_label: Label) -> void:
	press_label.text = "hold L1 to start"
	text_label.text = "NOICE"
	PlayerManager.set_player_active(playerNumber, true)
	
func manage_button_actions(player_number: int) -> void:
	#handle player 1 input
	if Input.is_action_pressed("P"+str(player_number)+" button 1"):
		if PlayerManager.get("player"+str(player_number)+"_active"):
			# hold to play mechanic
			#timer already running?
			if timerArray[player_number] and not timerArray[player_number].is_stopped():
				pass
			else:
				#start timer for level start
				timerArray[player_number] = Timer.new()
				get_tree().root.add_child(timerArray[player_number])
				timerArray[player_number].process_callback = Timer.TIMER_PROCESS_IDLE
				timerArray[player_number].start(hold_timer)
				timerArray[player_number].one_shot = true
				timerArray[player_number].timeout.connect(start_next_level)
		else:
			#set it active
			player1_ready(1, p1PressLabel, p1Label)
	else:
		if PlayerManager.player1_active:
			# hold to play mechanic
			# remove timer
			if timerArray[player_number]:
				timerArray[player_number].stop()
				p1ProgressBar.value = 0
	pass

func start_next_level() -> void:
	SceneSwitcher.switch_scene("res://level/map1.tscn")

func _process(delta: float) -> void:
	for timer in timerArray:
		if timer is Timer and not timer.is_stopped():
			var progress = (hold_timer - timer.time_left) / hold_timer * 100
			get("p"+str(timerArray.find(timer))+"ProgressBar").value = progress
		pass
		

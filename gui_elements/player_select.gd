extends Control

@export var hold_timer := 3.0

var p1label: Label
var p1PressLabel: Label
var p1ProgressBar: ProgressBar
var p1Timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	p1label = $VBoxContainer/row/col1/row1/VBoxContainer/Label1
	p1PressLabel = $VBoxContainer/row/col1/row1/VBoxContainer/PressLabel1
	p1ProgressBar = $VBoxContainer/row/col1/row1/VBoxContainer/ProgressBar1

func _input(event: InputEvent) -> void:
	print("P1 button 1 ", Input.is_action_pressed("P1 button 1"))
	if Input.is_action_pressed("P1 button 1"):
		if PlayerManager.player1_active:
			# hold to play mechanic
			#timer already running?
			if p1Timer and not p1Timer.is_stopped():
				print("timer already running")
				pass
			else:
				print("start timer")
				#start timer for level start
				p1Timer = Timer.new()
				get_tree().root.add_child(p1Timer)
				p1Timer.process_callback = Timer.TIMER_PROCESS_IDLE
				p1Timer.start(hold_timer)
				p1Timer.one_shot = true
				p1Timer.timeout.connect(start_next_level)
				print("p1 timer started ", p1Timer.time_left)
		else:
			#set it active
			PlayerManager.set_player_active(1, true)
			player1_ready()
			print("player 1 active")
	else:
		print("no p1 button1 active ", PlayerManager.player1_active)
		if PlayerManager.player1_active:
			# hold to play mechanic
			# remove timer
			print("p1timer ", p1Timer)
			if p1Timer:
				print("timer stoped")
				p1Timer.stop()
				p1ProgressBar.value = 0
		
	
func player1_ready() -> void:
	p1PressLabel.text = "hold L1 to start"
	p1label.text = "NOICE"

func start_next_level() -> void:
	print("NEW SCENE!")
	SceneSwitcher.switch_scene("res://level/map1.tscn")

func _process(delta: float) -> void:
	if p1Timer and not p1Timer.is_stopped():
		var progress = (hold_timer - p1Timer.time_left) / hold_timer * 100
		print("PROGRESS: ", progress)
		p1ProgressBar.value = progress

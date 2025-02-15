extends Node

# max 4 players
# every player has a corner for their stats?
# Stats needed?
# create internal class?
# - Health
# - Weapons array
# - some timeouts ?
# - spawner function
# - state mask (dead/alive/tumble/invincible/rolling?)
# - is_active bool
# - Voting state
# 
 
var player1_active := false
var player2_active := false
var player3_active := false
var player4_active := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var root = get_tree().root
	
func set_player_active(playernumber: int, active: bool):
	if playernumber == 1:
		player1_active = active
	if playernumber == 2:
		player2_active = active
	if playernumber == 3:
		player3_active = active
	if playernumber == 4:
		player4_active = active
		

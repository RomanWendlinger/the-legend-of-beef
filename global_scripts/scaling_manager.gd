extends Node
#Scaling ideas:
#	Ground level n 
#		-> enemy health 	= 100% + n * 10% ?
#		-> enemy damage 	= 100% + n * 10% ?
#		-> enemy speed 		= 100% + n * 10% ?
#			-> level 10 200% stats
#			-> level 20 300% stats
#	shop prices
#		3 items at base
#		reroll -> 10 coins * rerolls
#			10, 20, 30, 40, 50
#			
#		
#	Time scaling? 
#
## add on new map start
var ground_level := 0
# add stats ground_level * stat_grow_coeff
var enemy_stat_grow_coeff := .7
# how much more enemies spawn in a room
var enemy_amount_grow_coeff := 1
# numbers the shop has been rerolled yet
var shop_reroll_count := 0
# price added each reroll
var shop_reroll_grow_price := 10
# shop reroll total price
var shop_reroll_price := 10


func _ready() -> void:
	#listen to Signals
	SignalBus.shop_reroll.connect(shop_reroll_listener)
	SignalBus.enter_new_groundlevel.connect(new_groundlevel_listener)
	SignalBus.start_map_close.connect(new_groundlevel_listener)
	pass
func shop_reroll_listener() -> void:
	shop_reroll_count += 1
	shop_reroll_price += shop_reroll_grow_price
	
func new_groundlevel_listener() -> void:
	# only on map, needs to be better
	if SceneSwitcher.requested_scene == "res://level/map1.tscn":
		ground_level += 1
func scale_enemy(enemy: Enemy) -> Enemy:
	#enemy.damage += ground_level * enemy_stat_grow_coeff * enemy.damage 
	#enemy.max_speed += ground_level * enemy_stat_grow_coeff * enemy.max_speed 
	enemy.max_health += ground_level * enemy_stat_grow_coeff * enemy.max_health 
	enemy.health += ground_level * enemy_stat_grow_coeff * enemy.health 
	
	return enemy
	
	# the amount of enemies spawn in a room
func scale_enemy_spawn_numbers(enemy_number: int) -> int:
	return enemy_number + enemy_amount_grow_coeff * ground_level

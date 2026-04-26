extends Node
## keeps track of everything beer
# player number
# drunk amount (ml)
# drunk amount (bottles)
# current bottle volume (330ml, 500ml etc)
# current level (weight)
## second hand infos
# current rage/debuff offset from optimal bpm (100ml/6min)
# > every minute ahead
# beer bonus
# - 250ml at once -> 25% stat bonus
# currently most drunk volume of all
# -> get the crown
# 
var current_beer_stat = {
	"1" = {
		"drunk_amount" = 200,
		"bottle_drunk" = 0,
		"current_bottle_max_volume" = 500,
		"current_weight" = 240
	},
	"2" = {
		"drunk_amount" = 200,
		"bottle_drunk" = 0,
		"current_bottle_max_volume" = 500,
		"current_weight" = 400
	},
	"3" = {
		"drunk_amount" = 200,
		"bottle_drunk" = 0,
		"current_bottle_max_volume" = 500,
		"current_weight" = 100
	},
	"4" = {
		"drunk_amount" = 200,
		"bottle_drunk" = 0,
		"current_bottle_max_volume" = 500,
		"current_weight" = 450
	}
}

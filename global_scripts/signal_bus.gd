extends Node
class_name SignalBusGlobal

signal freeze_game_time(value: bool)

## player stuff
signal player_died
signal all_player_died
signal managed_player_died(player_number: int)
signal players_spawned
signal players_level_completed
signal player_health_update(player_number: int, health: float, max_health: float)
signal player_coin_update(player_number: int, coin_number: int)

## enemy stuff
signal final_boss_defeated(position: Vector2)
signal create_level_end_hole(position: Vector2)
signal enemy_defeated(enemy: Enemy)

#map loading and transition
signal start_ingame
signal start_postgame
signal start_map_close
signal start_map_load
signal start_pregame
signal enter_new_groundlevel

## scene switching
signal scene_transition(status: String)

#coin
signal coin_collected(body: Player, coin_value: int)

#pickup
signal pickup_collected(body: Player, pickupData: PickupData)

#gui
signal gui_update(player_number: int)

## stuff that scales
#shop
signal shop_reroll

## scene stuff
# all_player_died -> map_scene_ended (failed)
# level_completed -> map_scene_ended (success)

# map_scene_ended -> scene_transition

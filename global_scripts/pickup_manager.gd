extends Node

const COIN = preload("res://items/pickups/coin/coin.tscn")

func _ready() -> void:
	SignalBus.enemy_defeated.connect(enemy_defeated)
	SignalBus.coin_collected.connect(coin_collected)
	SignalBus.pickup_collected.connect(pickup_collected)
	
func enemy_defeated(enemy: Enemy) -> void:
	var coinInstance = COIN.instantiate()
	coinInstance.global_position = enemy.global_position
	get_tree().root.call_deferred("add_child", coinInstance)
	
func coin_collected(player: Player, coin_value: int) -> void:
	player.coin_count += coin_value
	SignalBus.player_coin_update.emit(player.player_number, player.coin_count)
	
func pickup_collected(entity: Player, pickup: Pickupable_Component) -> void:
	if entity is Player:
		match pickup.property:
			Pickupable_Component.PickupProperty.HEALTH:
					entity.healthNode.heal(pickup.property_value)
			Pickupable_Component.PickupProperty.MAX_HEALTH:
				entity.healthNode.max_health += pickup.property_value
				SignalBus.player_health_update.emit(entity.player_number, entity.health, entity.max_health)
			Pickupable_Component.PickupProperty.MAX_SPEED:
				entity.speed += pickup.property_value
			Pickupable_Component.PickupProperty.DAMAGE_PERCENTAGE:
				entity.current_weapon_damage_scale += pickup.property_value

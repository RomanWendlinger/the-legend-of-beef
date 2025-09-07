extends Interactable
class_name Buyable_Component

@export var price := 0
@export var price_label: Label 
@export var pickup_component: Pickupable_Component

func _ready() -> void:
	if price_label != null:
		price_label.visible = false
		if price > 0:
			price_label.text = str(price)+" coins"

func _on_body_entered(player: Player) -> void:
	super(player)
	if player is Player:
		if player.coin_count < price:
			price_label.self_modulate = Color(1,0,0,1)
		else:
			price_label.self_modulate = Color(1,1,1,1)
		price_label.visible = true
		
	pass # Replace with function body.


func _on_body_exited(body: Node2D) -> void:
	super(body)
	price_label.visible = false
	pass # Replace with function body.

func interact(player: Player) -> void:
	if player.coin_count > price:
		player.coin_count -= price
		SignalBus.player_coin_update.emit(player.player_number, player.coin_count)
		pickup_component.collect_item(player)
	else:
		pass

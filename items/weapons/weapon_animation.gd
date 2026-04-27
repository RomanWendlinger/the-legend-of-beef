extends Node
class_name WeaponAnimation

signal attack_finished
signal enemy_hit(body, impact_position: Vector2)
signal enemy_on_hit_hit(body, impact_position: Vector2)

var remove_animation_on_hit : bool
var remove_hurtbox_on_hit : bool

var animation_player: AnimationPlayer
@onready var hurtBox: Area2D = $sprite/Area2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player = get_node("AnimationPlayer")
	
func start_aim(direction: Vector2) -> void:
	self.rotation = direction.angle()
	animation_player.play("start_aim")
	
func aim(direction: Vector2) -> void:
	self.rotation = direction.angle()
	# check if start_aim is not finished yet
	if(animation_player.current_animation == "start_aim" && animation_player.current_animation_position < animation_player.current_animation_length):
		return
	animation_player.play("aim")
	
func attack() -> void:
	# start_aim was not finished yet, abort everything
	if(animation_player.current_animation == "start_aim" && animation_player.current_animation_position < animation_player.current_animation_length):
		remove_animation_element()
		return
	instant_attack()
	
func instant_attack() -> void:
	animation_player.play("attack")
	await animation_player.animation_finished
	if is_queued_for_deletion():
		return
	remove_animation_element()

func remove_animation_element() -> void:
	if is_queued_for_deletion():
		return
	# Disable collision detection to prevent signals after queue_free
	if hurtBox:
		hurtBox.set_deferred("monitoring", false)
		hurtBox.set_deferred("monitorable", false)

	animation_player.play("RESET")
	attack_finished.emit()
	self.queue_free()

func set_animation_speed_scale(time: float) -> void:
	animation_player.speed_scale = time
	
func set_direction(direction: Vector2) -> void:
	self.rotation = direction.angle()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy_character") or body is TileMapLayer or body.is_in_group("damageable"):
		enemy_hit.emit(body, hurtBox.global_position)
		if(remove_animation_on_hit):
			if(!self.is_queued_for_deletion()):
				remove_animation_element()
		if(remove_hurtbox_on_hit):
			remove_on_hit_hurtbox()
		
func _on_on_hit_area_2d_body_entered(body: Node2D) -> void:
	enemy_on_hit_hit.emit(body, hurtBox.global_position)
	# Disable the hurtbox after this physics step so it can't double-dip,
	# but the animation keeps playing. set_deferred is enough — wrapping in
	# call_deferred would race against self being queue_freed.
	remove_on_hit_hurtbox()

func remove_on_hit_hurtbox() -> void:
	if not is_instance_valid(hurtBox):
		return
	hurtBox.set_deferred("monitorable", false)
	hurtBox.set_deferred("monitoring", false)

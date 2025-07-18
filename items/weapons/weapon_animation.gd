extends Node

signal attack_finished

var animation_player: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player = get_node("AnimationPlayer")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func attack() -> void:
	self.visible = true
	animation_player.play("attack")
	await animation_player.animation_finished 
	on_attack_finished()
	
func on_attack_finished() -> void:
	self.visible = false
	
	animation_player.play("RESET")
	attack_finished.emit()
	queue_free()

func set_animation_speed_scale(time: float) -> void:
	animation_player.speed_scale = time
	
func set_flip_h(entry: bool) -> void:
	if(!entry):
		self.scale.x = -1

func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if body.is_in_group("enemy_character"):
		body.explode();
	pass # Replace with function body.

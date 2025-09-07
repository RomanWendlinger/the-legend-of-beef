extends ItemData
class_name WeaponData

@export var damage: float = 10.0
@export var interval: float = 5.0
@export var aimAnimationScale := 1.0
@export var attackAnimationScale := 1.0
@export var SwingAnimation: PackedScene
@export var projectile := false
## creates an absolute moving element that aims, not attached to the player
@export var absolute_aiming := false
## removes the whole animation when something is hit
@export var remove_animation_on_hit := true
## removes the hurtbox when something is hit
@export var remove_hurtbox_on_hit := true
@export var OnHitAnimation: PackedScene
@export var onHitDamage: float = 30.0
@export var onHitAnimationScale := 1.0

var anim: Node2D
var on_hit_anim: Node2D

var parent_node : Node

var flip_h := false

func set_parent(node: Node) -> void:
	parent_node = node

func start_aim(direction: Vector2) -> void:
	anim = SwingAnimation.instantiate()
	if(projectile == true || absolute_aiming):
		anim.global_position = parent_node.global_position
		parent_node.get_tree().root.add_child(anim)
	else:
		parent_node.add_child(anim)
	anim.set_animation_speed_scale(aimAnimationScale)
	anim.remove_hurtbox_on_hit = remove_hurtbox_on_hit
	anim.remove_animation_on_hit = remove_animation_on_hit
	if(absolute_aiming):
		anim.start_aim(Vector2.ZERO)
	else:
		anim.start_aim(direction)
	
func aim(direction: Vector2, delta) -> void:
	
	if(direction == Vector2.ZERO):
		return;
	if is_instance_valid(anim):
		if(absolute_aiming):
			#change position towards direction
			anim.global_position = anim.global_position + direction * 200 * delta
		else:
			#aim at direction
			anim.aim(direction)
	 
func attack(direction: Vector2) -> void:
	if is_instance_valid(anim):
		if(!absolute_aiming and direction != Vector2.ZERO):
			anim.set_direction(direction)
		anim.set_animation_speed_scale(attackAnimationScale)
		anim.attack()
		anim.enemy_hit.connect(on_enemy_hit)

func on_enemy_hit(body: Node2D, impact_position: Vector2) -> void:
	if(body.has_method("take_damage")):
		body.take_damage(get_damage(), impact_position)
	if(OnHitAnimation):
		start_on_hit_animation(impact_position)
		
func on_enemy_on_hit_hit(body: Node2D, impact_position: Vector2) -> void:
	body.take_damage(get_on_hit_damage(), impact_position)
	
#those two can be spiced with some modifiers later
func get_damage() -> float:
	
	return damage / 100.0 * (parent_node as Player).current_weapon_damage_scale
func get_on_hit_damage() -> float:
	return onHitDamage


func start_on_hit_animation(impact_position: Vector2) -> void:
	on_hit_anim = OnHitAnimation.instantiate()
	on_hit_anim.global_position = impact_position
	parent_node.get_tree().root.add_child(on_hit_anim)
	on_hit_anim.set_animation_speed_scale(onHitAnimationScale)
	on_hit_anim.enemy_on_hit_hit.connect(on_enemy_on_hit_hit)
	#shortcut to straight attack
	on_hit_anim.instant_attack()

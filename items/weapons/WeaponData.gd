extends ItemData
class_name WeaponData

@export var damage: float = 10.0
@export var interval: float = 5.0
@export var animationScale := 1.0
@export var SwingAnimation: PackedScene
@export var projectile := false

func attack() -> void:
	SwingAnimation.attack()

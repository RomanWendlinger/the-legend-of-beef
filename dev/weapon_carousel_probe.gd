extends Control

@onready var _carousel: WeaponCarousel = $WeaponCarousel
@onready var _log_label: Label = $VBoxContainer/LogLabel

const SLOT := 1
const _WEAPON_PATHS: Array[String] = [
	"res://items/weapons/goop/goop.tres",
	"res://items/weapons/knife/knife.tres",
	"res://items/weapons/Lightning/lightning.tres",
]


func _ready() -> void:
	var pool: Array[WeaponData] = []
	for path: String in _WEAPON_PATHS:
		var w: WeaponData = load(path)
		if w != null:
			pool.append(w)
	_carousel.weapons = pool
	_carousel.set_index(0)
	_carousel.visible = true
	_log_label.text = "Stick L/R to cycle. Button 1 to confirm."


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("P%d stick left" % SLOT):
		_carousel.cycle_left()
		_log("[cycle_left] now: %s" % _carousel.get_weapon().resource_path)
	elif Input.is_action_just_pressed("P%d stick right" % SLOT):
		_carousel.cycle_right()
		_log("[cycle_right] now: %s" % _carousel.get_weapon().resource_path)
	if Input.is_action_just_pressed("P%d button 1" % SLOT):
		_log("[confirm] weapon: %s" % _carousel.get_weapon().resource_path)
		print("[weapon_carousel_probe] confirmed: ", _carousel.get_weapon().resource_path)


func _log(msg: String) -> void:
	_log_label.text = msg

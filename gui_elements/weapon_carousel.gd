extends PanelContainer
class_name WeaponCarousel

@export var weapons: Array[WeaponData] = []

var _index: int = 0

@onready var _name_label: Label = $HBoxContainer/NameLabel


func _ready() -> void:
	_refresh()


func set_index(i: int) -> void:
	if weapons.is_empty():
		return
	_index = posmod(i, weapons.size())
	_refresh()


func get_weapon_index() -> int:
	return _index


func get_weapon() -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[_index]


func cycle_left() -> void:
	if weapons.is_empty():
		return
	_index = posmod(_index - 1, weapons.size())
	_refresh()


func cycle_right() -> void:
	if weapons.is_empty():
		return
	_index = posmod(_index + 1, weapons.size())
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if weapons.is_empty():
		_name_label.text = "---"
		return
	var w: WeaponData = weapons[_index]
	var display: String = w.name
	if display.is_empty():
		display = w.resource_path.get_file().get_basename().capitalize()
	_name_label.text = display

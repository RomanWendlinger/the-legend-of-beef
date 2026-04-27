extends PanelContainer
class_name CharacterCarousel

@export var options: Array[CharacterOption] = []

var _index: int = 0

@onready var _preview: TextureRect = $HBoxContainer/Preview
@onready var _name_label: Label = $HBoxContainer/NameLabel


func _ready() -> void:
	_refresh()


func set_index(i: int) -> void:
	if options.is_empty():
		return
	_index = posmod(i, options.size())
	_refresh()


func get_selected_index() -> int:
	return _index


func get_option() -> CharacterOption:
	if options.is_empty():
		return null
	return options[_index]


func cycle_left() -> void:
	if options.is_empty():
		return
	_index = posmod(_index - 1, options.size())
	_refresh()


func cycle_right() -> void:
	if options.is_empty():
		return
	_index = posmod(_index + 1, options.size())
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	if options.is_empty():
		_name_label.text = "---"
		_preview.visible = false
		return
	var opt: CharacterOption = options[_index]
	_name_label.text = opt.display_name
	if opt.is_bluesky or opt.preview_texture == null:
		_preview.visible = false
	else:
		_preview.visible = true
		var at := AtlasTexture.new()
		at.atlas = opt.preview_texture
		at.region = opt.preview_region
		_preview.texture = at

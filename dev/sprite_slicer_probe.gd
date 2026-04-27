extends Node2D

const SPRITE_PATH := "res://dev/sample_rpg_actor_sprite.png"
const CYCLE: Array[StringName] = [
	&"walk_down", &"walk_left", &"walk_right", &"walk_up",
	&"idle_down", &"idle_left", &"idle_right", &"idle_up",
]
const ANIM_DURATION := 3.0

var _anim_sprite: AnimatedSprite2D
var _label: Label
var _cycle_index := 0


func _ready() -> void:
	var png_bytes := FileAccess.get_file_as_bytes(SPRITE_PATH)
	if png_bytes.is_empty():
		push_error("[probe] could not read " + SPRITE_PATH)
		return

	var sf := SpriteSlicer.build_frames_from_png(png_bytes)
	if sf == null:
		push_error("[probe] SpriteSlicer.build_frames_from_png returned null")
		return

	print("[probe] SpriteFrames built OK. Animations: ", sf.get_animation_names())

	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.sprite_frames = sf
	_anim_sprite.position = Vector2(get_viewport().get_visible_rect().size / 2.0)
	_anim_sprite.scale = Vector2(4, 4)
	add_child(_anim_sprite)

	_label = Label.new()
	_label.position = Vector2(8, 8)
	add_child(_label)

	_play_current()


func _play_current() -> void:
	var anim := CYCLE[_cycle_index]
	_anim_sprite.play(anim)
	_label.text = str(anim)
	print("[probe] playing: ", anim)
	var t := get_tree().create_timer(ANIM_DURATION)
	await t.timeout
	_cycle_index = (_cycle_index + 1) % CYCLE.size()
	_play_current()

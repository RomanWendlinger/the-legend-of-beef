class_name SpriteSlicer

const FRAME_W := 48
const FRAME_H := 48
const COLS := 3
const ROWS := 4
const EXPECTED_W := 144
const EXPECTED_H := 192
const DEFAULT_FPS := 6

# Row indices per direction
const ROW_DOWN  := 0
const ROW_LEFT  := 1
const ROW_RIGHT := 2
const ROW_UP    := 3


## Builds a SpriteFrames with 8 animations from a 144x192 RPG.Actor PNG.
## Returns null if bytes are invalid or dimensions are not 144x192.
static func build_frames_from_png(png_bytes: PackedByteArray) -> SpriteFrames:
	if png_bytes.is_empty():
		return null

	var img := Image.new()
	if img.load_png_from_buffer(png_bytes) != OK:
		return null
	if img.get_width() != EXPECTED_W or img.get_height() != EXPECTED_H:
		return null

	var src_tex := ImageTexture.create_from_image(img)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	_add_idle(frames, src_tex, &"idle_down",  ROW_DOWN)
	_add_idle(frames, src_tex, &"idle_left",  ROW_LEFT)
	_add_idle(frames, src_tex, &"idle_right", ROW_RIGHT)
	_add_idle(frames, src_tex, &"idle_up",    ROW_UP)

	_add_walk(frames, src_tex, &"walk_down",  ROW_DOWN)
	_add_walk(frames, src_tex, &"walk_left",  ROW_LEFT)
	_add_walk(frames, src_tex, &"walk_right", ROW_RIGHT)
	_add_walk(frames, src_tex, &"walk_up",    ROW_UP)

	return frames


static func _add_idle(frames: SpriteFrames, src: ImageTexture, anim: StringName, row: int) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, false)
	frames.set_animation_speed(anim, DEFAULT_FPS)
	frames.add_frame(anim, _atlas(src, 0, row))


static func _add_walk(frames: SpriteFrames, src: ImageTexture, anim: StringName, row: int) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	frames.set_animation_speed(anim, DEFAULT_FPS)
	for col in COLS:
		frames.add_frame(anim, _atlas(src, col, row))


static func _atlas(src: ImageTexture, col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = src
	at.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
	return at

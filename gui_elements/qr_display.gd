extends Control

# Quiet zone: 4 modules on each side, as required by the QR spec.
const _QUIET := 4

@onready var _texture_rect: TextureRect = $TextureRect


func set_url(url: String) -> void:
	var matrix: Array = QrEncoder.encode_url(url)
	if matrix.is_empty():
		push_error("QrDisplay: encoding failed for url length %d" % url.length())
		_texture_rect.texture = null
		return
	_render(matrix)


func clear() -> void:
	_texture_rect.texture = null
	_texture_rect.visible = false


func _render(matrix: Array) -> void:
	var modules: int = matrix.size()
	var total: int = modules + _QUIET * 2

	# Pick a pixel scale so the image fits the Control's shorter axis without
	# fractional scaling (keeps modules crisp at any display size).
	var control_min: int = int(mini(int(size.x), int(size.y)))
	var scale: int = maxi(1, control_min / total)

	var img_size: int = total * scale
	var img := Image.create(img_size, img_size, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)

	for my in range(modules):
		for mx in range(modules):
			if matrix[my][mx]:
				var px: int = (mx + _QUIET) * scale
				var py: int = (my + _QUIET) * scale
				for dy in range(scale):
					for dx in range(scale):
						img.set_pixel(px + dx, py + dy, Color.BLACK)

	var tex := ImageTexture.create_from_image(img)
	_texture_rect.texture = tex
	# Disable bilinear filtering so the pixel grid stays sharp.
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.visible = true

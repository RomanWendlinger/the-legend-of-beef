extends Control

const URL_A := "https://bsky.social/oauth/authorize?client_id=https%3A%2F%2Frelay.the-legend-of-beef.todi.wtf%2Fclient-metadata.json&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Areq-8fa77f18bc9674015578d3c46a91ab20"
const URL_B := "https://bsky.social/oauth/authorize?client_id=https%3A%2F%2Frelay.the-legend-of-beef.todi.wtf%2Fclient-metadata.json&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Areq-deadbeef1234567890abcdef00112233"

@onready var _qr: Control = %QrDisplay
@onready var _label: Label = %UrlLabel
@onready var _swap_button: Button = %SwapButton

var _showing_a := true


func _ready() -> void:
	_swap_button.pressed.connect(_on_swap_pressed)
	_show(URL_A)


func _show(url: String) -> void:
	_label.text = url
	_qr.set_url(url)


func _on_swap_pressed() -> void:
	_showing_a = not _showing_a
	_show(URL_B if not _showing_a else URL_A)

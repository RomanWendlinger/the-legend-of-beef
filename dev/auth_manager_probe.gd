extends Control

@onready var _label: Label = %StatusLabel
@onready var _button: Button = %StartButton

const SLOT := 1
const TEST_HANDLE := "bsky.app"


func _ready() -> void:
	_button.pressed.connect(_on_start_pressed)
	AuthManager.login_started.connect(_on_login_started)
	AuthManager.login_completed.connect(_on_login_completed)
	AuthManager.login_failed.connect(_on_login_failed)


func _on_start_pressed() -> void:
	_button.disabled = true
	_label.text = "Resolving " + TEST_HANDLE + "..."
	AuthManager.start_login(SLOT, TEST_HANDLE)


func _on_login_started(slot: int, authorize_url: String) -> void:
	if slot != SLOT:
		return
	print("[auth_probe] authorize URL:\n", authorize_url)
	_label.text = authorize_url


func _on_login_completed(slot: int, did: String, handle: String) -> void:
	if slot != SLOT:
		return
	var msg := "OK: " + did + " (@" + handle + ")"
	print("[auth_probe] ", msg)
	_label.text = msg
	_button.disabled = false


func _on_login_failed(slot: int, error: String) -> void:
	if slot != SLOT:
		return
	var msg := "FAIL: " + error
	print("[auth_probe] ", msg)
	_label.text = msg
	_button.disabled = false

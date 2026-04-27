extends Control

@export var hold_timer := 1.0

enum SlotState { INACTIVE, IDLE, GUEST_JOINED, BSKY_PENDING, BSKY_AUTHED, BSKY_FAILED, BSKY_ALLOCATING }

var _slot_state := {
	1: SlotState.INACTIVE,
	2: SlotState.INACTIVE,
	3: SlotState.INACTIVE,
	4: SlotState.INACTIVE,
}

var timerArray: Array[Timer]

const _CHARACTER_OPTIONS: Array[String] = [
	"res://players/options/granny.tres",
	"res://players/options/wzrd.tres",
	"res://players/options/frbll.tres",
	"res://players/options/fast_boi.tres",
	"res://players/options/bluesky.tres",
]

const _WEAPON_POOL: Array[String] = [
	"res://items/weapons/goop/goop.tres",
	"res://items/weapons/knife/knife.tres",
	"res://items/weapons/Lightning/lightning.tres",
]

var _selected_weapon_idx: Dictionary = { 1: 0, 2: 0, 3: 0, 4: 0 }

# Loaded once in _ready, shared across all weapon carousel instances.
var _weapon_pool_loaded: Array[WeaponData] = []

# Loaded once in _ready, shared across all character carousel instances.
var _character_options_loaded: Array[CharacterOption] = []

# Stick repeat cooldown per slot for carousel cycling.
var _carousel_cooldown: Dictionary = { 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0 }
const _CAROUSEL_REPEAT_DELAY := 0.18

@onready var _labels: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/Label1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/Label2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/Label3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/Label4,
}
@onready var _press_labels: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/PressLabel1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/PressLabel2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/PressLabel3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/PressLabel4,
}
@onready var _progress_bars: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/ProgressBar1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/ProgressBar2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/ProgressBar3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/ProgressBar4,
}
@onready var _stat_panels: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/StatPanel1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/StatPanel2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/StatPanel3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/StatPanel4,
}
@onready var _qr_displays: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/QrDisplay1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/QrDisplay2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/QrDisplay3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/QrDisplay4,
}
@onready var _allocators: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/StatAllocator1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/StatAllocator2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/StatAllocator3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/StatAllocator4,
}
@onready var _weapon_carousels: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/WeaponCarousel1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/WeaponCarousel2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/WeaponCarousel3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/WeaponCarousel4,
}
@onready var _character_carousels: Dictionary = {
	1: $VBoxContainer/row/col1/row1/VBoxContainer/CharacterCarousel1,
	2: $VBoxContainer/row/col2/row1/VBoxContainer/CharacterCarousel2,
	3: $VBoxContainer/row2/col1/row1/VBoxContainer/CharacterCarousel3,
	4: $VBoxContainer/row2/col2/row1/VBoxContainer/CharacterCarousel4,
}

# Per-slot: true if save failed and player is playing with an unsynced budget.
var _stats_unsynced: Dictionary = { 1: false, 2: false, 3: false, 4: false }
# Holds the Bluesky handle during allocation so we can re-enter authed state.
var _pending_handles: Dictionary = { 1: "", 2: "", 3: "", 4: "" }

var _auth_manager: Node


func _ready() -> void:
	timerArray.resize(5)
	PlayerManager.active_players.clear()

	_auth_manager = get_node("/root/AuthManager")
	_auth_manager.login_started.connect(_on_login_started)
	_auth_manager.login_completed.connect(_on_login_completed)
	_auth_manager.login_failed.connect(_on_login_failed)

	for path: String in _WEAPON_POOL:
		var w: WeaponData = load(path)
		if w != null:
			_weapon_pool_loaded.append(w)

	for path: String in _CHARACTER_OPTIONS:
		var opt: CharacterOption = load(path)
		if opt != null:
			_character_options_loaded.append(opt)

	for n in [1, 2, 3, 4]:
		var alloc: StatAllocator = _allocators[n]
		alloc.slot_number = n
		alloc.save_requested.connect(_on_allocator_save_requested.bind(n))
		alloc.cancel_requested.connect(_on_allocator_cancel_requested.bind(n))

		var wcarousel: WeaponCarousel = _weapon_carousels[n]
		wcarousel.weapons = _weapon_pool_loaded
		wcarousel.set_index(0)

		var ccarousel: CharacterCarousel = _character_carousels[n]
		ccarousel.options = _character_options_loaded
		ccarousel.set_index(0)

	# Slots start inactive — player presses Btn1 to join, which moves them to IDLE.
	for n in [1, 2, 3, 4]:
		_enter_inactive(n)


func _input(event: InputEvent) -> void:
	for n in [1, 2, 3, 4]:
		if event.is_action_pressed("P%d button 1" % n):
			_handle_button1_pressed(n)
		if event.is_action_pressed("P%d button 2" % n):
			_handle_button2_pressed(n)


func _process(delta: float) -> void:
	for n in [1, 2, 3, 4]:
		_poll_hold_timer(n)
		_poll_carousel_input(n, delta)


func _poll_carousel_input(n: int, delta: float) -> void:
	var state: SlotState = _slot_state[n]
	_carousel_cooldown[n] -= delta
	if _carousel_cooldown[n] > 0.0:
		return

	if state == SlotState.IDLE:
		var ccarousel: CharacterCarousel = _character_carousels[n]
		if Input.is_action_pressed("P%d stick left" % n):
			ccarousel.cycle_left()
			_carousel_cooldown[n] = _CAROUSEL_REPEAT_DELAY
		elif Input.is_action_pressed("P%d stick right" % n):
			ccarousel.cycle_right()
			_carousel_cooldown[n] = _CAROUSEL_REPEAT_DELAY
	elif state == SlotState.GUEST_JOINED or state == SlotState.BSKY_AUTHED:
		var wcarousel: WeaponCarousel = _weapon_carousels[n]
		if Input.is_action_pressed("P%d stick left" % n):
			wcarousel.cycle_left()
			_selected_weapon_idx[n] = wcarousel.get_weapon_index()
			PlayerManager.set_selected_weapon(n, wcarousel.get_weapon())
			_carousel_cooldown[n] = _CAROUSEL_REPEAT_DELAY
		elif Input.is_action_pressed("P%d stick right" % n):
			wcarousel.cycle_right()
			_selected_weapon_idx[n] = wcarousel.get_weapon_index()
			PlayerManager.set_selected_weapon(n, wcarousel.get_weapon())
			_carousel_cooldown[n] = _CAROUSEL_REPEAT_DELAY


func _handle_button1_pressed(n: int) -> void:
	match _slot_state[n]:
		SlotState.INACTIVE:
			_enter_idle(n)
		SlotState.IDLE:
			var ccarousel: CharacterCarousel = _character_carousels[n]
			var opt: CharacterOption = ccarousel.get_option()
			if opt == null:
				return
			if opt.is_bluesky:
				_enter_bsky_pending(n)
			else:
				PlayerManager.set_selected_character(n, opt)
				_enter_guest_joined(n, opt)
		SlotState.BSKY_PENDING:
			_auth_manager.cancel_login(n)
			_enter_idle(n)
		SlotState.GUEST_JOINED, SlotState.BSKY_AUTHED:
			_start_hold_timer(n)
		# BSKY_ALLOCATING: button 1 confirm is handled inside StatAllocator._input


func _handle_button2_pressed(n: int) -> void:
	match _slot_state[n]:
		SlotState.BSKY_AUTHED:
			_enter_bsky_allocating(n)


func _poll_hold_timer(n: int) -> void:
	if _slot_state[n] != SlotState.GUEST_JOINED and _slot_state[n] != SlotState.BSKY_AUTHED:
		return
	if not Input.is_action_pressed("P%d button 1" % n):
		if is_instance_valid(timerArray[n]):
			timerArray[n].stop()
		_progress_bars[n].value = 0
		return
	if is_instance_valid(timerArray[n]) and not timerArray[n].is_stopped():
		_progress_bars[n].value = (hold_timer - timerArray[n].time_left) / hold_timer * 100.0


func _start_hold_timer(n: int) -> void:
	if is_instance_valid(timerArray[n]) and not timerArray[n].is_stopped():
		return
	var t := Timer.new()
	get_tree().root.get_children()[0].add_child(t)
	t.process_callback = Timer.TIMER_PROCESS_IDLE
	t.one_shot = true
	t.start(hold_timer)
	t.timeout.connect(start_next_level)
	timerArray[n] = t


func _enter_inactive(n: int) -> void:
	_slot_state[n] = SlotState.INACTIVE
	PlayerManager.set_player_active(n, false)
	_labels[n].text = "Player %d\n" % n
	_press_labels[n].text = "Press Btn1 to join"
	_progress_bars[n].value = 0
	_stat_panels[n].visible = false
	_allocators[n].visible = false
	_weapon_carousels[n].visible = false
	_character_carousels[n].visible = false
	_qr_displays[n].clear()


func _enter_idle(n: int) -> void:
	_slot_state[n] = SlotState.IDLE
	PlayerManager.set_player_active(n, false)
	_labels[n].text = "Player %d\n" % n
	_press_labels[n].text = "Stick L/R to choose, Btn1 to confirm"
	_progress_bars[n].value = 0
	_stat_panels[n].visible = false
	_allocators[n].visible = false
	_weapon_carousels[n].visible = false
	_character_carousels[n].visible = true
	_qr_displays[n].clear()
	_qr_displays[n].visible = false


func _enter_guest_joined(n: int, opt: CharacterOption) -> void:
	_slot_state[n] = SlotState.GUEST_JOINED
	PlayerManager.set_player_active(n, true)
	_labels[n].text = "NOICE"
	_press_labels[n].text = "hold Button to start"
	_character_carousels[n].visible = false
	_qr_displays[n].visible = false
	_carousel_cooldown[n] = 0.0
	_weapon_carousels[n].visible = true
	PlayerManager.set_selected_weapon(n, _weapon_carousels[n].get_weapon())
	_show_stat_panel_for_option(n, opt)


func _enter_bsky_pending(n: int) -> void:
	_slot_state[n] = SlotState.BSKY_PENDING
	_labels[n].text = "Player %d\n" % n
	_press_labels[n].text = "Scan to log in\n(Button 1 to cancel)"
	_stat_panels[n].visible = false
	_weapon_carousels[n].visible = false
	_character_carousels[n].visible = false
	_qr_displays[n].visible = false
	_auth_manager.start_login(n, "bsky.app")


func _enter_bsky_authed(n: int, real_handle: String, budget: StatBudget) -> void:
	_slot_state[n] = SlotState.BSKY_AUTHED
	PlayerManager.set_player_active(n, true)
	_labels[n].text = "@" + real_handle
	_press_labels[n].text = "hold Button to start"
	_qr_displays[n].clear()
	_qr_displays[n].visible = false
	_character_carousels[n].visible = false
	_stat_panels[n].set_stats(budget)
	_stat_panels[n].visible = true
	_carousel_cooldown[n] = 0.0
	_weapon_carousels[n].visible = true
	PlayerManager.set_selected_weapon(n, _weapon_carousels[n].get_weapon())


func _enter_bsky_failed(n: int, error: String) -> void:
	_slot_state[n] = SlotState.BSKY_FAILED
	_labels[n].text = "Login failed"
	_press_labels[n].text = error.left(40)
	_qr_displays[n].visible = false
	var t := get_tree().create_timer(3.0)
	await t.timeout
	# Scene may have switched during the 3s wait — bail before touching @onready nodes.
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if _slot_state[n] == SlotState.BSKY_FAILED:
		_enter_idle(n)


func _enter_bsky_allocating(n: int) -> void:
	_slot_state[n] = SlotState.BSKY_ALLOCATING
	_labels[n].text = "Allocate Stats"
	_press_labels[n].text = "Btn1 save  Btn2 cancel"
	_stat_panels[n].visible = false
	_weapon_carousels[n].visible = false
	_character_carousels[n].visible = false
	_qr_displays[n].visible = false
	var budget: StatBudget = _auth_manager.get_stat_budget(n)
	if budget == null:
		budget = _default_budget()
	_allocators[n].set_initial(budget)
	_allocators[n].set_status("")
	_allocators[n].set_busy(false)
	_allocators[n].visible = true


# ── AuthManager signal handlers ───────────────────────────────────────────────

func _on_login_started(slot: int, authorize_url: String) -> void:
	if _slot_state[slot] != SlotState.BSKY_PENDING:
		return
	_qr_displays[slot].set_url(authorize_url)
	_qr_displays[slot].visible = true


func _on_login_completed(slot: int, did: String, real_handle: String) -> void:
	if _slot_state[slot] != SlotState.BSKY_PENDING:
		return
	_fetch_stats_and_enter_authed(slot, did, real_handle)


func _on_login_failed(slot: int, error: String) -> void:
	if _slot_state[slot] != SlotState.BSKY_PENDING:
		return
	_enter_bsky_failed(slot, error)


func _on_allocator_cancel_requested(slot: int) -> void:
	if _slot_state[slot] != SlotState.BSKY_ALLOCATING:
		return
	var budget: StatBudget = _auth_manager.get_stat_budget(slot)
	if budget == null:
		budget = _default_budget()
	var handle: String = _pending_handles.get(slot, "")
	_allocators[slot].visible = false
	_enter_bsky_authed(slot, handle, budget)


func _on_allocator_save_requested(budget: StatBudget, slot: int) -> void:
	if _slot_state[slot] != SlotState.BSKY_ALLOCATING:
		return
	_allocators[slot].set_status("Saving...")
	_allocators[slot].set_busy(true)
	_do_save(slot, budget)


func _do_save(slot: int, budget: StatBudget) -> void:
	var ok: bool = await _auth_manager.save_stats(slot, budget)
	if _slot_state[slot] != SlotState.BSKY_ALLOCATING:
		return
	if ok:
		_stats_unsynced[slot] = false
		_auth_manager.set_stat_budget(slot, budget)
		_allocators[slot].visible = false
		var handle: String = _pending_handles.get(slot, "")
		_enter_bsky_authed(slot, handle, budget)
	else:
		_allocators[slot].set_busy(false)
		_allocators[slot].set_status("Save failed — Btn1 retry, Btn2 cancel")
		_stats_unsynced[slot] = true


# ── Stats fetch after auth ────────────────────────────────────────────────────

func _fetch_stats_and_enter_authed(slot: int, did: String, real_handle: String) -> void:
	var budget := _default_budget()
	var is_default := true
	var pds: String = _auth_manager.get_pds(slot)
	if not pds.is_empty():
		var record := await AtprotoHelpers.get_record(self, pds, did, "actor.rpg.stats")
		if record is Dictionary and record.has("value"):
			var game_data = (record["value"] as Dictionary).get("the_legend_of_beef")
			if game_data is Dictionary:
				var parsed := _parse_stats(game_data)
				if parsed != null:
					budget = parsed
					is_default = false
	_auth_manager.set_stat_budget(slot, budget)
	_pending_handles[slot] = real_handle
	if is_default:
		_enter_bsky_allocating(slot)
	else:
		_enter_bsky_authed(slot, real_handle, budget)


func _parse_stats(data: Dictionary) -> StatBudget:
	var b := StatBudget.new()
	b.vit = data.get("vit", 6)
	b.str_stat = data.get("str_stat", 6)
	b.agi = data.get("agi", 6)
	b.tgh = data.get("tgh", 6)
	var within_budget := b.clamp_and_default()
	if not within_budget:
		return null
	return b


func _default_budget() -> StatBudget:
	var b := StatBudget.new()
	b.vit = 6
	b.str_stat = 6
	b.agi = 6
	b.tgh = 6
	return b


# ── Helpers ───────────────────────────────────────────────────────────────────

func _show_stat_panel_for_option(player_number: int, opt: CharacterOption) -> void:
	if opt.stats_path.is_empty():
		return
	var budget: StatBudget = load(opt.stats_path)
	if budget == null:
		return
	_stat_panels[player_number].set_stats(budget)
	_stat_panels[player_number].visible = true


func start_next_level() -> void:
	stop_bars()
	SceneSwitcher.switch_scene("res://level/map1.tscn")


func stop_bars() -> void:
	for timer in timerArray:
		if is_instance_valid(timer):
			timer.stop()

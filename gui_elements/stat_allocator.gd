extends Control
class_name StatAllocator

signal save_requested(budget: StatBudget)
signal cancel_requested

@export var slot_number: int = 1

# stat names in order: used by rows
const _STAT_NAMES: Array[String] = ["VIT", "STR", "AGI", "TGH"]
# cursor: 0-3 = stat rows, 4 = Save, 5 = Cancel
var _cursor: int = 0
var _values: Array[int] = [6, 6, 6, 6]
var _busy: bool = false

# input repeat state
var _stick_cooldown: float = 0.0
const _STICK_REPEAT_DELAY := 0.18

@onready var _rows: Array[HBoxContainer] = [
	$VBoxContainer/Row0,
	$VBoxContainer/Row1,
	$VBoxContainer/Row2,
	$VBoxContainer/Row3,
]
@onready var _val_labels: Array[Label] = [
	$VBoxContainer/Row0/ValLabel,
	$VBoxContainer/Row1/ValLabel,
	$VBoxContainer/Row2/ValLabel,
	$VBoxContainer/Row3/ValLabel,
]
@onready var _total_label: Label = $VBoxContainer/TotalLabel
@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _save_btn: Button = $VBoxContainer/ButtonRow/SaveBtn
@onready var _cancel_btn: Button = $VBoxContainer/ButtonRow/CancelBtn


func set_initial(budget: StatBudget) -> void:
	_values[0] = budget.vit
	_values[1] = budget.str_stat
	_values[2] = budget.agi
	_values[3] = budget.tgh
	_cursor = 0
	_busy = false
	_refresh()


func set_status(text: String) -> void:
	_status_label.text = text


func set_busy(busy: bool) -> void:
	_busy = busy
	_save_btn.disabled = busy
	_cancel_btn.disabled = busy


func set_slot(n: int) -> void:
	slot_number = n


# ── internal ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _on_visibility_changed() -> void:
	set_process(visible)
	if visible:
		_stick_cooldown = 0.0


func _process(delta: float) -> void:
	if _busy:
		return
	_stick_cooldown -= delta
	if _stick_cooldown > 0.0:
		return

	var p := slot_number
	var moved := false

	if Input.is_action_pressed("P%d stick up" % p):
		_cursor = (_cursor - 1 + 6) % 6
		moved = true
	elif Input.is_action_pressed("P%d stick down" % p):
		_cursor = (_cursor + 1) % 6
		moved = true
	elif Input.is_action_pressed("P%d stick left" % p) and _cursor < 4:
		_decrement(_cursor)
		moved = true
	elif Input.is_action_pressed("P%d stick right" % p) and _cursor < 4:
		_increment(_cursor)
		moved = true

	if moved:
		_stick_cooldown = _STICK_REPEAT_DELAY
		_refresh()


func _input(event: InputEvent) -> void:
	if not visible or _busy:
		return
	var p := slot_number
	if event.is_action_pressed("P%d button 1" % p):
		_on_confirm()
	elif event.is_action_pressed("P%d button 2" % p):
		cancel_requested.emit()


func _on_confirm() -> void:
	if _total_cost() != StatBudget.POINT_BUDGET:
		return
	var b := StatBudget.new()
	b.vit = _values[0]
	b.str_stat = _values[1]
	b.agi = _values[2]
	b.tgh = _values[3]
	save_requested.emit(b)


func _increment(idx: int) -> void:
	if _values[idx] >= StatBudget.STAT_MAX:
		return
	# Cost of next level: 1 if still in normal tier, 2 if in premium tier.
	var step_cost := 2 if _values[idx] >= StatBudget.STAT_PIVOT else 1
	if _total_cost() + step_cost > StatBudget.POINT_BUDGET:
		return
	_values[idx] += 1


func _decrement(idx: int) -> void:
	if _values[idx] <= StatBudget.STAT_MIN:
		return
	_values[idx] -= 1


func _total_cost() -> int:
	var t := 0
	for v: int in _values:
		t += StatBudget.cost(v)
	return t


func _refresh() -> void:
	for i in range(4):
		_val_labels[i].text = str(_values[i])
		# Premium-tier stats get a gold tint so the player sees they've gone deep.
		if _values[i] > StatBudget.STAT_PIVOT:
			_val_labels[i].modulate = Color(1.0, 0.85, 0.2)
		else:
			_val_labels[i].modulate = Color(1, 1, 1)
		var row: HBoxContainer = _rows[i]
		if _cursor == i:
			row.modulate = Color(1.0, 0.95, 0.2)
		else:
			row.modulate = Color(1, 1, 1)

	var t := _total_cost()
	_total_label.text = "Total: %d/%d" % [t, StatBudget.POINT_BUDGET]
	if t == StatBudget.POINT_BUDGET:
		_total_label.modulate = Color(0.2, 1.0, 0.4)
	else:
		_total_label.modulate = Color(1, 1, 1)

	_save_btn.modulate = Color(1.0, 0.95, 0.2) if _cursor == 4 else Color(1, 1, 1)
	_cancel_btn.modulate = Color(1.0, 0.95, 0.2) if _cursor == 5 else Color(1, 1, 1)

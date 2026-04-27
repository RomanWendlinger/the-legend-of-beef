extends Control

@onready var _allocator: StatAllocator = $StatAllocator
@onready var _log_label: Label = $VBoxContainer/LogLabel

const SLOT := 1


func _ready() -> void:
	var initial := StatBudget.new()
	initial.vit = 6
	initial.str_stat = 6
	initial.agi = 6
	initial.tgh = 6
	_allocator.set_slot(SLOT)
	_allocator.set_initial(initial)
	_allocator.visible = true
	_allocator.save_requested.connect(_on_save_requested)
	_allocator.cancel_requested.connect(_on_cancel_requested)


func _on_save_requested(budget: StatBudget) -> void:
	var msg := "save_requested: VIT=%d STR=%d AGI=%d TGH=%d cost=%d/%d" % [
		budget.vit, budget.str_stat, budget.agi, budget.tgh,
		budget.total_cost(), StatBudget.POINT_BUDGET
	]
	print("[stat_allocator_probe] ", msg)
	_log_label.text = msg


func _on_cancel_requested() -> void:
	print("[stat_allocator_probe] cancelled")
	_log_label.text = "cancelled"

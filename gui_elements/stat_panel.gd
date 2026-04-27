extends PanelContainer

@onready var _vit_label: Label = $VBoxContainer/VitLabel
@onready var _str_label: Label = $VBoxContainer/StrLabel
@onready var _agi_label: Label = $VBoxContainer/AgiLabel
@onready var _tgh_label: Label = $VBoxContainer/TghLabel

func set_stats(budget: StatBudget) -> void:
	_vit_label.text = "VIT  %d" % budget.vit
	_str_label.text = "STR  %d" % budget.str_stat
	_agi_label.text = "AGI  %d" % budget.agi
	_tgh_label.text = "TGH  %d" % budget.tgh

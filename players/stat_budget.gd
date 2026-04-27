extends Resource
class_name StatBudget

const STAT_MIN := 1
# Above STAT_PIVOT each point costs 2 from the budget — specialization is expensive.
# Max achievable is 15 (3 stats at 1 + budget left for one stat: 10 base + (24-3-10)/2 = 5 extras).
const STAT_PIVOT := 10
const STAT_MAX := 15
const POINT_BUDGET := 24

@export var vit: int = 6
@export var str_stat: int = 6
@export var agi: int = 6
@export var tgh: int = 6

# Budget cost of taking a single stat from 0 to `value`.
# 1 point per stat-level up to the pivot (10), 2 points per level beyond.
static func cost(value: int) -> int:
	if value <= STAT_PIVOT:
		return value
	return STAT_PIVOT + 2 * (value - STAT_PIVOT)

func total_cost() -> int:
	return cost(vit) + cost(str_stat) + cost(agi) + cost(tgh)

static func is_valid(budget: StatBudget) -> bool:
	var in_range := (
		budget.vit >= STAT_MIN and budget.vit <= STAT_MAX and
		budget.str_stat >= STAT_MIN and budget.str_stat <= STAT_MAX and
		budget.agi >= STAT_MIN and budget.agi <= STAT_MAX and
		budget.tgh >= STAT_MIN and budget.tgh <= STAT_MAX
	)
	return in_range and budget.total_cost() <= POINT_BUDGET

func clamp_and_default() -> bool:
	vit = clampi(vit, STAT_MIN, STAT_MAX)
	str_stat = clampi(str_stat, STAT_MIN, STAT_MAX)
	agi = clampi(agi, STAT_MIN, STAT_MAX)
	tgh = clampi(tgh, STAT_MIN, STAT_MAX)
	return total_cost() <= POINT_BUDGET

func to_derived_stats() -> Dictionary:
	return {
		"max_health": get_max_health(),
		"current_weapon_damage_scale": get_damage_scale(),
		"speed": get_speed(),
		"pushback_strength": get_pushback_strength(),
	}

func get_max_health() -> int:
	return _lerp_stat(vit, 50, 400)

func get_damage_scale() -> float:
	return _lerp_stat(str_stat, 60, 260)

func get_speed() -> float:
	return _lerp_stat(agi, 70, 250)

func get_pushback_strength() -> float:
	return _lerp_stat(tgh, 40, 240)

func _lerp_stat(stat: int, min_val: float, max_val: float) -> float:
	return min_val + float(stat - 1) / 9.0 * (max_val - min_val)

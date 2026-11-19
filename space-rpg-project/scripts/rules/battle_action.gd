class_name BattleAction
extends RefCounted
## One thing a unit can do with its actions (shoot, scan, first aid...).
##
## `effect` is called as effect(unit, target, battle) and returns
##   {"text": String for the combat log, "refund": int actions to give back}.
## `target` is null for actions that don't need one.
## `requirement` (optional) is called as requirement(unit) and returns "" if the
## action is possible, or a reason it isn't (e.g. "Weapon is jammed").

var id: String
var display_name: String
var cost: int = 1
var focused: bool = false
var needs_target: bool = false
var description: String = ""
var effect: Callable
var requirement: Callable


static func make(p_id: String, p_name: String, p_cost: int, p_focused: bool,
		p_description: String, p_effect: Callable) -> BattleAction:
	var a := BattleAction.new()
	a.id = p_id
	a.display_name = p_name
	a.cost = p_cost
	a.focused = p_focused
	a.description = p_description
	a.effect = p_effect
	return a


## Reason this unit can't use the action right now ("" = it can), apart from
## the turn budget rules.
func blocked_reason(unit: Unit) -> String:
	if requirement.is_valid():
		return requirement.call(unit)
	return ""


func button_text() -> String:
	return "%s  [%d]" % [display_name, cost]

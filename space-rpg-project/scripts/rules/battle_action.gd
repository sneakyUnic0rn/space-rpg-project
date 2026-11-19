class_name BattleAction
extends RefCounted
## One thing a unit can do with its actions (shoot, scan, first aid...).
## `effect` is a function that takes the acting Unit and returns
## {"text": String for the combat log, "refund": int actions to give back}.

var id: String
var display_name: String
var cost: int = 1
var focused: bool = false
var description: String = ""
var effect: Callable


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


func button_text() -> String:
	return "%s  [%d]" % [display_name, cost]

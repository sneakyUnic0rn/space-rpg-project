class_name TurnBudget
extends RefCounted
## What one unit may still do this turn.
## Rules: 1 move + 2 actions per turn, the same action can't be taken twice,
## and "focused" actions (2-action ones like First Aid or Full Search) must be
## the unit's first action of the turn. Moving first is allowed.

const MOVES_PER_TURN := 1
const ACTIONS_PER_TURN := 2

var moves_left := MOVES_PER_TURN
var actions_left := ACTIONS_PER_TURN
var actions_taken := 0
var used_ids: Array[String] = []


func reset() -> void:
	moves_left = MOVES_PER_TURN
	actions_left = ACTIONS_PER_TURN
	actions_taken = 0
	used_ids.clear()


func can_move() -> bool:
	return moves_left > 0


func use_move() -> void:
	moves_left = maxi(0, moves_left - 1)


## Empty string if the action is allowed, otherwise the reason it isn't.
func why_not(action: BattleAction) -> String:
	if action.id in used_ids:
		return "%s was already used this turn" % action.display_name
	if action.focused and actions_taken > 0:
		return "%s is a focused action and must be your first action" % action.display_name
	if action.cost > actions_left:
		return "%s needs %d actions, you have %d" % [action.display_name, action.cost, actions_left]
	return ""


func can_take(action: BattleAction) -> bool:
	return why_not(action) == ""


func spend(action: BattleAction) -> void:
	actions_left -= action.cost
	actions_taken += 1
	used_ids.append(action.id)


## Give actions back (e.g. Hard success on a focused action). Never above the max.
func refund(amount: int) -> void:
	actions_left = mini(actions_left + amount, ACTIONS_PER_TURN)


func is_exhausted() -> bool:
	return moves_left == 0 and actions_left == 0

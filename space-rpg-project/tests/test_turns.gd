extends SceneTree
## Checks for the action economy and turn flow. Run with:
##   godot --headless --script res://tests/test_turns.gd

var _failures := 0
var _passes := 0


func _initialize() -> void:
	test_budget_rules()
	await test_turn_flow()
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func expect(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)


func test_budget_rules() -> void:
	var scan := ActionLibrary.quick_scan()
	var search := ActionLibrary.full_search()
	var other := BattleAction.make("other", "Other", 1, false, "", func(_u): return {})

	var b := TurnBudget.new()
	expect(b.can_move() and b.actions_left == 2, "turn starts with 1 move + 2 actions")
	b.use_move()
	expect(not b.can_move(), "only one move per turn")
	expect(b.can_take(search), "focused action allowed after moving (still first ACTION)")

	b.reset()
	b.spend(scan)
	expect(not b.can_take(scan), "same action can't be taken twice in a turn")
	expect(b.why_not(scan).contains("already used"), "reason explains the repeat rule")
	expect(not b.can_take(search), "focused action blocked once another action was taken")
	expect(b.can_take(other), "a different 1-action action is still allowed")
	b.spend(other)
	expect(b.actions_left == 0 and not b.can_take(other), "no actions left after two")

	b.reset()
	b.spend(search)
	expect(b.actions_left == 0, "focused action costs both actions")
	b.refund(1)
	expect(b.actions_left == 1 and b.can_take(scan), "refund gives one action back for another action")
	b.refund(5)
	expect(b.actions_left == 2, "refund never goes above the max")

	b.reset()
	b.use_move()
	b.spend(scan)
	b.spend(other)
	expect(b.is_exhausted(), "move + 2 actions = unit is done")


func test_turn_flow() -> void:
	Dice.set_seed(7)
	var scene: Node3D = load("res://scenes/battle/battle_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var u: Unit = scene.selected
	expect(scene.round_number == 1 and scene.is_player_phase, "battle starts on round 1, player turn")

	var moved: bool = await scene.try_move_to(u.cell + Vector2i(0, 2))
	expect(moved, "first move works")
	var moved_again: bool = await scene.try_move_to(u.cell + Vector2i(0, 1))
	expect(not moved_again, "second move in the same turn is refused")

	var scan: BattleAction = scene.actions[0]
	expect(scene.perform_action(scan), "Quick Scan (by id) uses an action")
	expect(not scene.perform_action(scan), "Quick Scan can't be repeated")
	expect(u.budget.actions_left >= 0, "budget never negative")

	# Use up this unit and the other one; turn should end automatically.
	u.budget.actions_left = 0
	scene._after_unit_acted()
	expect(scene.selected != u, "exhausted unit hands control to the next unit")
	var other: Unit = scene.selected
	other.budget.use_move()
	other.budget.actions_left = 0
	scene._after_unit_acted()
	expect(not scene.is_player_phase, "turn ends automatically when every unit is done")

	await create_timer(scene.ENEMY_PHASE_TIME + 0.3).timeout
	expect(scene.is_player_phase and scene.round_number == 2, "enemy phase passes and round 2 begins")
	expect(u.budget.can_move() and u.budget.actions_left == 2, "budgets reset for the new round")
	expect(scene.hud.log_text().contains("Round 2"), "combat log shows the new round")

	# Manual end turn
	scene.end_player_turn()
	expect(not scene.is_player_phase, "End Turn starts the enemy phase")
	await create_timer(scene.ENEMY_PHASE_TIME + 0.3).timeout
	expect(scene.round_number == 3, "round 3 after ending turn manually")
	scene.queue_free()

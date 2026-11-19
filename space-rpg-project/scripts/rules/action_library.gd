class_name ActionLibrary
## The actions available in the test battle. Real actions (shoot, first aid,
## combat hack, overwatch...) get added here as they're built.


static func default_actions() -> Array[BattleAction]:
	return [quick_scan(), full_search()]


## 1 action: a quick Perception check. Placeholder effect until enemies,
## loot and hidden things exist.
static func quick_scan() -> BattleAction:
	return BattleAction.make("quick_scan", "Quick Scan", 1, false,
		"Perception check to spot threats nearby.",
		func(unit: Unit) -> Dictionary:
			var r := unit.stats.check_skill("Perception")
			return {"text": "%s Quick Scan: %s" % [unit.name, r.describe()], "refund": 0})


## 2 actions, focused (must be first). Hard or better success refunds 1 action.
static func full_search() -> BattleAction:
	return BattleAction.make("full_search", "Full Search", 2, true,
		"Focused: thorough Perception check. Hard success refunds 1 action.",
		func(unit: Unit) -> Dictionary:
			var r := unit.stats.check_skill("Perception")
			var refund := 1 if r.is_hard_or_better() else 0
			var text := "%s Full Search: %s" % [unit.name, r.describe()]
			if refund > 0:
				text += "  ->  %s success, 1 action refunded!" % r.level_name()
			return {"text": text, "refund": refund})

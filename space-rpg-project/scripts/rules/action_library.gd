class_name ActionLibrary
## The actions available in the test battle, following the Actions table in
## "Space Tactics RPG: Core Systems Design". More get added as they're built.


static func default_actions() -> Array[BattleAction]:
	return [shoot(), aim(), reload(), clear_jam(), quick_scan(), full_search()]


## 1 action: one weapon attack. Needs a target.
static func shoot() -> BattleAction:
	var a := BattleAction.make("attack", "Shoot", 1, false,
		"One attack with your weapon against an enemy you can see.",
		func(unit: Unit, target: Unit, battle) -> Dictionary:
			return {"text": Combat.attack(battle.grid, unit, target)["text"], "refund": 0})
	a.needs_target = true
	a.requirement = func(unit: Unit) -> String:
		if unit.weapon == null: return "No weapon"
		if unit.weapon.jammed: return "Weapon is jammed: Clear Jam first"
		if unit.weapon.ammo <= 0: return "Out of ammo: Reload first"
		return ""
	return a


## 1 action: bonus die on your next attack this turn.
static func aim() -> BattleAction:
	var a := BattleAction.make("aim", "Aim", 1, false,
		"Bonus die on your next attack this turn.",
		func(unit: Unit, _target, _battle) -> Dictionary:
			unit.aim_bonus = 1
			return {"text": "%s takes aim (+1 bonus die on the next shot)." % unit.name, "refund": 0})
	a.requirement = func(unit: Unit) -> String:
		if "attack" in unit.budget.used_ids: return "Already attacked this turn, Aim would be wasted"
		return ""
	return a


## 1 action: refill the magazine.
static func reload() -> BattleAction:
	var a := BattleAction.make("reload", "Reload", 1, false,
		"Refill the magazine.",
		func(unit: Unit, _target, _battle) -> Dictionary:
			unit.weapon.ammo = unit.weapon.mag
			return {"text": "%s reloads (%s)." % [unit.name, unit.weapon.ammo_text()], "refund": 0})
	a.requirement = func(unit: Unit) -> String:
		if unit.weapon == null: return "No weapon"
		if unit.weapon.ammo >= unit.weapon.mag: return "Magazine is already full"
		return ""
	return a


## 1 action: clear a jammed weapon ("clearing it takes an action").
static func clear_jam() -> BattleAction:
	var a := BattleAction.make("clear_jam", "Clear Jam", 1, false,
		"Clear a jammed weapon so it can fire again.",
		func(unit: Unit, _target, _battle) -> Dictionary:
			unit.weapon.jammed = false
			return {"text": "%s clears the jam." % unit.name, "refund": 0})
	a.requirement = func(unit: Unit) -> String:
		if unit.weapon == null or not unit.weapon.jammed: return "Weapon isn't jammed"
		return ""
	return a


## 1 action: a quick Perception check. Placeholder effect until there's
## anything hidden to find.
static func quick_scan() -> BattleAction:
	return BattleAction.make("quick_scan", "Quick Scan", 1, false,
		"Perception check to scan for enemies, exits and hazards.",
		func(unit: Unit, _target, _battle) -> Dictionary:
			var r := unit.stats.check_skill("Perception")
			return {"text": "%s Quick Scan: %s" % [unit.name, r.describe()], "refund": 0})


## 2 actions, focused (must be first). Hard or better success refunds 1 action.
static func full_search() -> BattleAction:
	return BattleAction.make("full_search", "Search", 2, true,
		"Focused: thorough Perception check. Hard success refunds 1 action.",
		func(unit: Unit, _target, _battle) -> Dictionary:
			var r := unit.stats.check_skill("Perception")
			var refund := 1 if r.is_hard_or_better() else 0
			var text := "%s Search: %s" % [unit.name, r.describe()]
			if refund > 0:
				text += "  ->  %s success, 1 action refunded!" % r.level_name()
			return {"text": text, "refund": refund})

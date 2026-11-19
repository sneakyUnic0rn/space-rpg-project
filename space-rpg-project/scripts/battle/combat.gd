class_name Combat
## Attack rules from "Fractured Frontier Weapons (d100)":
##   roll d100 vs weapon skill.  Over skill = miss.  Regular = damage - armour.
##   Hard = hit + Edge.  Extreme = maximum damage + Edge.  >= Malf = jam, no shot.
## Bonus/penalty dice: Aim +1, half cover -1, full cover -2, long range -1,
## point blank +1 (pistols/SMGs) or -1 (rifles), Bulky under STR 50 -1, Braced after moving -1.

const LEAN := 0.9  # how far a unit can step out of its tile (XCOM-style) to see around corners


# --- Line of sight -----------------------------------------------------------

## Can a unit at `from` see `to`? Walls (#) block, crates (h) don't.
## Units may lean out to an open side, so you can shoot around a corner.
static func has_line_of_sight(grid: BattleGrid, from: Vector2i, to: Vector2i) -> bool:
	var target := Vector2(to) + Vector2(0.5, 0.5)
	for origin in _lean_points(grid, from):
		if _clear_line(grid, origin, target, from, to):
			return true
	return false


static func _lean_points(grid: BattleGrid, cell: Vector2i) -> Array[Vector2]:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	var points: Array[Vector2] = [center]
	for dir in GridPathfinder.STRAIGHT:
		if grid.is_floor(cell + dir):
			points.append(center + Vector2(dir) * LEAN)
	return points


static func _clear_line(grid: BattleGrid, a: Vector2, b: Vector2, from: Vector2i, to: Vector2i) -> bool:
	var steps := int(ceil(a.distance_to(b) / 0.1))
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		var cell := Vector2i(floori(p.x), floori(p.y))
		if cell == from or cell == to:
			continue
		if grid.terrain(cell) == "#":
			return false
	return true


# --- Cover -------------------------------------------------------------------

## Cover the target gets against this shooter: 0 none, 1 half, 2 full.
## Only cover right next to the target, on the side facing the shooter, counts.
static func cover_against(grid: BattleGrid, target: Vector2i, shooter: Vector2i) -> int:
	var to_shooter := shooter - target
	var best := 0
	for dir in GridPathfinder.STRAIGHT:
		var c := grid.cover_at(target + dir)
		if c > 0 and to_shooter.x * dir.x + to_shooter.y * dir.y > 0:
			best = maxi(best, c)
	return best


static func distance_m(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a).distance_to(Vector2(b)) * Weapon.METRES_PER_TILE


# --- Attack preview ----------------------------------------------------------

## Everything about a possible shot, without rolling. Used for the hover preview
## and by the attack itself, so what you see is exactly what gets rolled.
static func preview(grid: BattleGrid, shooter: Unit, target: Unit) -> Dictionary:
	var w := shooter.weapon
	var p := {"ok": false, "reason": "", "bonus_penalty": 0, "notes": [], "skill": 0,
		"hit_chance": 0.0, "distance_m": 0.0, "cover": 0}
	if w == null:
		p.reason = "No weapon"
		return p
	if w.jammed:
		p.reason = "%s is jammed" % w.weapon_name
		return p
	if w.ammo <= 0:
		p.reason = "%s is empty, reload first" % w.weapon_name
		return p
	if not has_line_of_sight(grid, shooter.cell, target.cell):
		p.reason = "No line of sight"
		return p

	var dist := distance_m(shooter.cell, target.cell)
	p.distance_m = dist
	if dist > w.range_m * 2:
		p.reason = "Out of range (%.0f m, max %.0f m)" % [dist, w.range_m * 2]
		return p

	var bp := 0
	var notes: Array[String] = []
	if shooter.aim_bonus > 0:
		bp += 1
		notes.append("Aimed +1")
	if dist > w.range_m:
		bp -= 1
		notes.append("Long range -1")
	var adjacent := maxi(absi(shooter.cell.x - target.cell.x), absi(shooter.cell.y - target.cell.y)) <= 1
	if adjacent and w.point_blank == "bonus":
		bp += 1
		notes.append("Point blank +1")
	elif adjacent and w.point_blank == "penalty":
		bp -= 1
		notes.append("Point blank -1")
	var cover := 0 if w.has("Ignores Cover") else cover_against(grid, target.cell, shooter.cell)
	p.cover = cover
	if cover == 1:
		bp -= 1
		notes.append("Half cover -1")
	elif cover == 2:
		bp -= 2
		notes.append("Full cover -2")
	if w.has("Bulky") and shooter.stats.get_attribute("STR") < 50:
		bp -= 1
		notes.append("Bulky -1")
	if w.has("Braced") and not shooter.budget.can_move():
		bp -= 1
		notes.append("Braced, moved -1")

	bp = clampi(bp, -SkillCheck.MAX_BONUS_PENALTY, SkillCheck.MAX_BONUS_PENALTY)
	p.bonus_penalty = bp
	p.notes = notes
	p.skill = shooter.stats.get_skill(w.skill)
	p.hit_chance = hit_chance(p.skill, bp, w.malf)
	p.ok = true
	return p


## Exact chance to hit: roll at or under the skill, and below the Malf number.
static func hit_chance(skill: int, bonus_penalty: int, malf: int) -> float:
	var dist := Dice.d100_distribution(bonus_penalty)
	var total := 0.0
	for roll in range(1, mini(skill, malf - 1) + 1):
		total += dist[roll]
	return total


# --- Resolve -----------------------------------------------------------------

## Fire one shot. Returns {"text", "hit", "damage", "killed"}.
static func attack(grid: BattleGrid, shooter: Unit, target: Unit) -> Dictionary:
	var p := preview(grid, shooter, target)
	var out := {"text": "", "hit": false, "damage": 0, "killed": false}
	if not p.ok:
		out.text = "Can't shoot: %s" % p.reason
		return out

	var w := shooter.weapon
	shooter.aim_bonus = 0
	var roll := Dice.roll_d100(p.bonus_penalty)
	var level := SkillCheck.level_for(roll, p.skill)
	var dice_note := "" if p.bonus_penalty == 0 else " (%+d dice)" % p.bonus_penalty
	var head := "%s -> %s: rolled %d vs %d%s" % [shooter.name, target.name, roll, p.skill, dice_note]

	if roll >= w.malf:
		w.jammed = true
		out.text = "%s  JAMMED! (Malf %d+). Clear Jam to fire again." % [head, w.malf]
		return out

	w.ammo -= 1

	if level < SkillCheck.Level.REGULAR:
		var miss_by: int = roll - p.skill
		if w.edge == "Graze" and miss_by <= 10:
			var graze := Dice.roll_expression("1d3")
			out.damage = graze
			out.killed = target.take_damage(graze)
			out.text = "%s  Miss, but Graze deals %d." % [head, graze]
		else:
			out.text = "%s  MISS." % head
		return out

	out.hit = true
	var dice := w.damage_dice(p.distance_m)
	var raw := 0
	var level_text := "Hit"
	if level >= SkillCheck.Level.EXTREME:
		raw = Dice.max_expression(dice)
		level_text = "EXTREME hit (max damage)"
	else:
		raw = Dice.roll_expression(dice)
		if level == SkillCheck.Level.HARD:
			level_text = "Hard hit"
	var armour := w.effective_armour(target.armour)
	var dmg := maxi(0, raw - armour)
	out.damage = dmg
	out.killed = target.take_damage(dmg)

	var text := "%s  %s! %s = %d" % [head, level_text, dice, raw]
	if armour > 0:
		text += " - %d armour" % armour
	text += " -> %d damage." % dmg
	if level >= SkillCheck.Level.HARD and w.edge != "" and w.edge != "Graze":
		text += " Edge: %s (not in game yet)." % w.edge
	if out.killed:
		text += " %s is down!" % target.name
	out.text = text
	return out

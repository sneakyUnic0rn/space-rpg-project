class_name Dice
## All randomness in the game goes through here.
## One shared generator means we can seed it for repeatable tests and replays.

static var rng := RandomNumberGenerator.new()


## Fix the sequence of rolls (useful for tests and bug reports).
static func set_seed(value: int) -> void:
	rng.seed = value


## Roll one die with the given number of sides, e.g. roll(6) -> 1..6.
static func roll(sides: int) -> int:
	return rng.randi_range(1, sides)


## Roll several dice and add them up, e.g. roll_many(2, 6) for 2d6.
static func roll_many(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += roll(sides)
	return total


## Roll d100 the Call of Cthulhu way: a tens die (00-90) plus a units die (0-9).
## "00" + "0" counts as 100. Result is always 1..100.
##
## bonus_penalty > 0 means bonus dice: roll extra tens dice and keep the LOWEST.
## bonus_penalty < 0 means penalty dice: roll extra tens dice and keep the HIGHEST.
## Bonus and penalty dice cancel each other out before you call this.
static func roll_d100(bonus_penalty: int = 0) -> int:
	var units := rng.randi_range(0, 9)
	var tens_options: Array[int] = []
	for i in 1 + absi(bonus_penalty):
		tens_options.append(rng.randi_range(0, 9) * 10)

	var best := 100
	var worst := 0
	for tens in tens_options:
		var value := _combine(tens, units)
		best = mini(best, value)
		worst = maxi(worst, value)

	if bonus_penalty > 0:
		return best
	if bonus_penalty < 0:
		return worst
	return _combine(tens_options[0], units)


## Roll a dice expression like "2d6+2", "1d10" or "3d8-1".
static func roll_expression(expr: String) -> int:
	var p := parse_expression(expr)
	return roll_many(p.x, p.y) + p.z


## The highest possible result of an expression (used for Extreme hits).
static func max_expression(expr: String) -> int:
	var p := parse_expression(expr)
	return p.x * p.y + p.z


## "2d6+2" -> Vector3i(2, 6, 2). Count, sides, flat bonus.
static func parse_expression(expr: String) -> Vector3i:
	var re := RegEx.create_from_string("^\\s*(\\d*)d(\\d+)\\s*([+-]\\s*\\d+)?\\s*$")
	var m := re.search(expr)
	if m == null:
		push_error("Bad dice expression: '%s'" % expr)
		return Vector3i.ZERO
	var count := 1 if m.get_string(1) == "" else int(m.get_string(1))
	var bonus := 0 if m.get_string(3) == "" else int(m.get_string(3).replace(" ", ""))
	return Vector3i(count, int(m.get_string(2)), bonus)


static var _d100_cache := {}

## Exact probability of each d100 result (index 1..100) with bonus/penalty dice.
## Used for hit-chance previews, so players see real odds.
static func d100_distribution(bonus_penalty: int) -> PackedFloat64Array:
	if _d100_cache.has(bonus_penalty):
		return _d100_cache[bonus_penalty]
	var dist := PackedFloat64Array()
	dist.resize(101)
	var n := 1 + absi(bonus_penalty)
	var combos := int(pow(10, n))
	var weight := 1.0 / (combos * 10)
	for units in 10:
		for c in combos:
			var best := 100
			var worst := 0
			var first := -1
			var rest := c
			for i in n:
				var value := _combine((rest % 10) * 10, units)
				rest /= 10
				if first < 0:
					first = value
				best = mini(best, value)
				worst = maxi(worst, value)
			var result := first
			if bonus_penalty > 0:
				result = best
			elif bonus_penalty < 0:
				result = worst
			dist[result] += weight
	_d100_cache[bonus_penalty] = dist
	return dist


static func _combine(tens: int, units: int) -> int:
	var value := tens + units
	return 100 if value == 0 else value

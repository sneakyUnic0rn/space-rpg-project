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


static func _combine(tens: int, units: int) -> int:
	var value := tens + units
	return 100 if value == 0 else value

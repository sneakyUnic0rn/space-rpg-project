class_name SkillCheck
## d100 roll-under skill checks with Call of Cthulhu success levels.
##
##   Critical  roll of 01
##   Extreme   roll <= skill / 5
##   Hard      roll <= skill / 2
##   Regular   roll <= skill
##   Failure   anything above the skill
##   Fumble    100, or 96-100 when the skill is below 50

enum Level { FUMBLE, FAILURE, REGULAR, HARD, EXTREME, CRITICAL }

## Bonus/penalty dice are capped like in CoC.
const MAX_BONUS_PENALTY := 2


## Everything about one check, so the UI and combat log can explain what happened.
class Result:
	var skill_value: int
	var roll: int
	var level: Level
	var required: Level
	var bonus_penalty: int

	## Did the roll reach the required success level?
	func succeeded() -> bool:
		return level >= required

	## True on Hard, Extreme or Critical. Used for things like the
	## "focused action refunds one action" rule.
	func is_hard_or_better() -> bool:
		return level >= Level.HARD

	func level_name() -> String:
		return SkillCheck.level_to_string(level)

	func describe() -> String:
		var dice_note := ""
		if bonus_penalty > 0:
			dice_note = " (+%d bonus)" % bonus_penalty
		elif bonus_penalty < 0:
			dice_note = " (%d penalty)" % bonus_penalty
		return "Rolled %d vs %d%s -> %s (needed %s) -> %s" % [
			roll, skill_value, dice_note, level_name(),
			SkillCheck.level_to_string(required),
			"SUCCESS" if succeeded() else "FAIL",
		]


## Make a check. `required` is the difficulty: REGULAR for normal,
## HARD or EXTREME for tougher tasks.
static func check(skill_value: int, required: Level = Level.REGULAR, bonus_penalty: int = 0) -> Result:
	bonus_penalty = clampi(bonus_penalty, -MAX_BONUS_PENALTY, MAX_BONUS_PENALTY)
	var r := Result.new()
	r.skill_value = skill_value
	r.required = required
	r.bonus_penalty = bonus_penalty
	r.roll = Dice.roll_d100(bonus_penalty)
	r.level = level_for(r.roll, skill_value)
	return r


## Pure rule: which success level does this roll give for this skill?
## Kept separate from the dice so it can be tested exactly.
static func level_for(roll: int, skill_value: int) -> Level:
	if roll == 1:
		return Level.CRITICAL
	var fumble_from := 100 if skill_value >= 50 else 96
	if roll >= fumble_from:
		return Level.FUMBLE
	if roll <= skill_value / 5:
		return Level.EXTREME
	if roll <= skill_value / 2:
		return Level.HARD
	if roll <= skill_value:
		return Level.REGULAR
	return Level.FAILURE


static func level_to_string(level: Level) -> String:
	return Level.keys()[level].capitalize()

extends SceneTree
## Automated checks for the rules core. Run from the project folder with:
##   godot --headless --script res://tests/test_rules.gd
## Prints PASS/FAIL per test and exits with code 1 if anything failed.

var _failures := 0
var _passes := 0


func _initialize() -> void:
	test_level_for_boundaries()
	test_d100_range_and_distribution()
	test_bonus_and_penalty_dice()
	test_character_skills()
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func expect(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)


func test_level_for_boundaries() -> void:
	var L := SkillCheck.Level
	# Skill 60: Extreme <= 12, Hard <= 30, Regular <= 60, fumble only on 100.
	expect(SkillCheck.level_for(1, 60) == L.CRITICAL, "01 is always Critical")
	expect(SkillCheck.level_for(12, 60) == L.EXTREME, "12 vs 60 is Extreme")
	expect(SkillCheck.level_for(13, 60) == L.HARD, "13 vs 60 is Hard")
	expect(SkillCheck.level_for(30, 60) == L.HARD, "30 vs 60 is Hard")
	expect(SkillCheck.level_for(31, 60) == L.REGULAR, "31 vs 60 is Regular")
	expect(SkillCheck.level_for(60, 60) == L.REGULAR, "60 vs 60 is Regular")
	expect(SkillCheck.level_for(61, 60) == L.FAILURE, "61 vs 60 fails")
	expect(SkillCheck.level_for(99, 60) == L.FAILURE, "99 vs 60 fails, not a fumble")
	expect(SkillCheck.level_for(100, 60) == L.FUMBLE, "100 is a fumble")
	# Skill 40: fumble range widens to 96-100.
	expect(SkillCheck.level_for(95, 40) == L.FAILURE, "95 vs 40 fails")
	expect(SkillCheck.level_for(96, 40) == L.FUMBLE, "96 vs 40 is a fumble")
	# Difficulty
	var r := SkillCheck.Result.new()
	r.level = L.REGULAR
	r.required = L.HARD
	expect(not r.succeeded(), "Regular result fails a Hard check")
	r.level = L.EXTREME
	expect(r.succeeded() and r.is_hard_or_better(), "Extreme passes a Hard check")


func test_d100_range_and_distribution() -> void:
	Dice.set_seed(12345)
	var n := 100000
	var counts := {}
	var lo := 1000
	var hi := -1
	for i in n:
		var v := Dice.roll_d100()
		lo = mini(lo, v)
		hi = maxi(hi, v)
		counts[v] = counts.get(v, 0) + 1
	expect(lo == 1 and hi == 100, "d100 covers exactly 1..100 (got %d..%d)" % [lo, hi])
	expect(counts.size() == 100, "every value 1..100 appears")
	# Each value should come up about 1% of the time.
	var worst := 0.0
	for v in counts:
		worst = maxf(worst, absf(counts[v] / float(n) - 0.01))
	expect(worst < 0.002, "d100 is uniform (max deviation %.4f)" % worst)


func test_bonus_and_penalty_dice() -> void:
	Dice.set_seed(99)
	var n := 50000
	var sums := {0: 0.0, 1: 0.0, -1: 0.0, 2: 0.0, -2: 0.0}
	for bp in sums:
		for i in n:
			sums[bp] += Dice.roll_d100(bp)
		sums[bp] /= n
	print("      average roll: normal %.1f | +1 bonus %.1f | +2 bonus %.1f | -1 penalty %.1f | -2 penalty %.1f"
		% [sums[0], sums[1], sums[2], sums[-1], sums[-2]])
	expect(sums[2] < sums[1] and sums[1] < sums[0], "bonus dice lower the roll (good for roll-under)")
	expect(sums[-2] > sums[-1] and sums[-1] > sums[0], "penalty dice raise the roll")


func test_character_skills() -> void:
	var c := CharacterStats.new()
	c.attributes["DEX"] = 70
	c.attributes["STR"] = 50
	c.skill_points["Firearms"] = 20
	expect(c.get_skill("Firearms") == 55, "Firearms = DEX 70 / 2 + 20 points = 55")
	expect(c.get_skill("Melee") == 25, "Melee = STR 50 / 2 = 25")
	expect(c.get_skill("Melee", "DEX") == 35, "Finesse Melee uses DEX: 70 / 2 = 35")
	expect(c.get_skill("Hacking") == 10, "Hacking uses its fixed base of 10")
	c.skill_points["Firearms"] = 90
	expect(c.get_skill("Firearms") == 100, "skills cap at 100")
	var result := c.check_skill("Firearms")
	expect(result.roll >= 1 and result.roll <= 100, "check_skill returns a valid roll")

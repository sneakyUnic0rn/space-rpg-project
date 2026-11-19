extends SceneTree
## Checks for shooting: dice, odds, line of sight, cover, damage, jams, ammo. Run with:
##   godot --headless --script res://tests/test_combat.gd

var _failures := 0
var _passes := 0


func _initialize() -> void:
	test_dice_and_odds()
	test_weapons_data()
	await test_los_and_cover()
	await test_attacks()
	await test_shoot_in_battle()
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func expect(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)


func test_dice_and_odds() -> void:
	expect(Dice.parse_expression("2d6+2") == Vector3i(2, 6, 2), "parses 2d6+2")
	expect(Dice.parse_expression("d8") == Vector3i(1, 8, 0), "parses d8")
	expect(Dice.max_expression("2d10+2") == 22, "max of 2d10+2 is 22")
	Dice.set_seed(1)
	var lo := 99
	var hi := 0
	for i in 2000:
		var v := Dice.roll_expression("2d6+2")
		lo = mini(lo, v)
		hi = maxi(hi, v)
	expect(lo == 4 and hi == 14, "2d6+2 rolls 4..14")

	for bp in [-2, -1, 0, 1, 2]:
		var total := 0.0
		for v in Dice.d100_distribution(bp):
			total += v
		expect(is_equal_approx(total, 1.0), "d100 odds with %+d dice add up to 100%%" % bp)
	expect(is_equal_approx(Combat.hit_chance(60, 0, 101), 0.60), "plain skill 60 hits 60% of the time")
	expect(is_equal_approx(Combat.hit_chance(60, 0, 99), 0.60), "Malf 99 doesn't affect skill 60")
	var with_bonus := Combat.hit_chance(60, 1, 101)
	var with_penalty := Combat.hit_chance(60, -1, 101)
	var with_two := Combat.hit_chance(60, -2, 101)
	print("      skill 60: +1 die %.1f%% | normal 60%% | -1 die %.1f%% | -2 dice %.1f%%" % [with_bonus * 100, with_penalty * 100, with_two * 100])
	expect(with_bonus > 0.6 and with_penalty < 0.6 and with_two < with_penalty, "bonus raises and penalty lowers the odds")

	# Simulated rolls should match the exact odds.
	Dice.set_seed(5)
	var hits := 0
	for i in 40000:
		if Dice.roll_d100(-1) <= 60:
			hits += 1
	expect(absf(hits / 40000.0 - with_penalty) < 0.01, "simulated -1 odds match the exact calculation")


func test_weapons_data() -> void:
	var rifle := Weapon.create("Assault Rifle")
	expect(rifle.mag == 24 and rifle.ammo == 24 and rifle.skill == "Firearms", "Assault Rifle loads from data")
	var shotgun := Weapon.create("Pump Shotgun")
	expect(shotgun.damage_dice(3.0) == "3d6" and shotgun.damage_dice(10.0) == "2d6" and shotgun.damage_dice(40.0) == "1d6",
		"shotgun damage drops with range bands")
	expect(Weapon.create("Sniper Rifle").effective_armour(5) == 2, "armour-piercing halves armour (round down)")
	expect(Weapon.create("Laser Pistol").effective_armour(6) == 0, "energy weapons ignore armour")
	expect(DataDB.entry("armour", "Composite Vest")["value"] == 3, "armour data loads")
	for name in DataDB.table("weapons"):
		var w := Weapon.create(name)
		var dice := w.damage_dice(1.0)
		if Dice.max_expression(dice) <= 0:
			expect(false, "%s has valid damage dice" % name)
			return
	expect(true, "every weapon in weapons.json has valid damage dice")


## Small test map:
##   ##########
##   #........#   y=1
##   #...h....#   y=2   crate at (4,2)
##   #........#   y=3
##   #...##...#   y=4   walls at (4,4),(5,4)
##   #........#   y=5
##   ##########
func _make_grid() -> BattleGrid:
	var g := BattleGrid.new()
	g.layout = "##########\n#........#\n#...h....#\n#........#\n#...##...#\n#........#\n##########"
	root.add_child(g)
	g.build()
	return g


func test_los_and_cover() -> void:
	var g := _make_grid()
	await process_frame
	expect(Combat.has_line_of_sight(g, Vector2i(1, 1), Vector2i(8, 1)), "clear row has line of sight")
	expect(Combat.has_line_of_sight(g, Vector2i(1, 2), Vector2i(8, 2)), "crates don't block line of sight")
	expect(not Combat.has_line_of_sight(g, Vector2i(4, 3), Vector2i(4, 5)), "wall blocks line of sight")
	expect(not Combat.has_line_of_sight(g, Vector2i(5, 1), Vector2i(4, 5)), "wall blocks a diagonal shot through it")
	expect(Combat.has_line_of_sight(g, Vector2i(5, 5), Vector2i(6, 3)), "stepping out past a wall corner gives sight")
	expect(not Combat.has_line_of_sight(g, Vector2i(5, 5), Vector2i(5, 3)), "but not straight through the wall")

	# Target at (5,2) is right of the crate at (4,2).
	expect(Combat.cover_against(g, Vector2i(5, 2), Vector2i(1, 2)) == 1, "crate between = half cover")
	expect(Combat.cover_against(g, Vector2i(5, 2), Vector2i(8, 2)) == 0, "shooter on the open side = no cover (flanked)")
	expect(Combat.cover_against(g, Vector2i(5, 2), Vector2i(5, 1)) == 0, "shooter from above = no cover")
	# Target at (4,3) has the wall (4,4) below it.
	expect(Combat.cover_against(g, Vector2i(4, 3), Vector2i(3, 5)) == 2, "wall between = full cover")
	expect(Combat.cover_against(g, Vector2i(4, 3), Vector2i(4, 1)) == 1, "shooting from the crate side = half cover from the crate")
	g.queue_free()


func _unit(team: String, cell: Vector2i, weapon: String, armour: String, g: BattleGrid) -> Unit:
	var u := Unit.new()
	u.team = team
	u.name = team + str(cell)
	u.stats.attributes = {"STR": 50, "DEX": 60, "CON": 50, "INT": 40, "WIS": 40, "CHA": 40}
	u.stats.skill_points = {"Firearms": 30}
	root.add_child(u)
	u.equip(weapon, armour)
	u.place_at(cell, g)
	return u


func test_attacks() -> void:
	var g := _make_grid()
	await process_frame
	var shooter := _unit("player", Vector2i(1, 2), "Assault Rifle", "None", g)
	var target := _unit("enemy", Vector2i(5, 2), "Service Revolver", "Composite Vest", g)
	expect(shooter.hp == 10 and shooter.max_hp == 10, "HP = (CON 50 + STR 50) / 10 = 10")

	var p := Combat.preview(g, shooter, target)
	expect(p.ok and p.skill == 60, "preview: Firearms 60 (DEX 60 / 2 + 30)")
	expect(p.bonus_penalty == -1 and "Half cover -1" in p.notes, "preview: crate gives -1 die")
	expect(is_equal_approx(p.distance_m, 6.0), "4 tiles = 6 m")

	shooter.aim_bonus = 1
	p = Combat.preview(g, shooter, target)
	expect(p.bonus_penalty == 0, "Aim cancels the cover penalty")
	shooter.aim_bonus = 0

	var close := _unit("enemy", Vector2i(2, 2), "Service Revolver", "None", g)
	p = Combat.preview(g, shooter, close)
	expect("Point blank -1" in p.notes, "rifle at point blank takes a penalty die")
	var revolver_p := Combat.preview(g, close, shooter)
	expect("Point blank +1" in revolver_p.notes, "revolver at point blank gets a bonus die")
	close.queue_free()

	# Run many attacks with fresh targets and check the rules hold.
	Dice.set_seed(42)
	var hits := 0
	var jams := 0
	var extreme_ok := true
	var armour_ok := true
	var n := 3000
	for i in n:
		target.hp = 99
		target.max_hp = 99
		shooter.weapon.jammed = false
		shooter.weapon.ammo = 24
		var r := Combat.attack(g, shooter, target)
		if r.text.contains("JAMMED"):
			jams += 1
			if shooter.weapon.ammo != 24:
				armour_ok = false  # a jam must not use ammo
			continue
		if shooter.weapon.ammo != 23:
			armour_ok = false
		if r.hit:
			hits += 1
			if r.damage > 12 - 3 or r.damage < 0:
				armour_ok = false  # 2d6 - 3 armour is 0..9
			if r.text.contains("EXTREME") and r.damage != 9:
				extreme_ok = false
	var expected := Combat.hit_chance(60, -1, 99)
	print("      %d shots: hit %.1f%% (expected %.1f%%), jams %d" % [n, hits * 100.0 / n, expected * 100, jams])
	expect(absf(hits / float(n) - expected) < 0.03, "hit rate matches the previewed hit chance")
	expect(jams > 0 and jams < n * 0.05, "jams happen, rarely (Malf 99+ with a penalty die)")
	expect(armour_ok, "damage is 2d6 minus 3 armour, and each shot uses exactly 1 round")
	expect(extreme_ok, "Extreme hits do maximum damage (12 - 3 = 9)")

	# Jam / ammo blocking
	shooter.weapon.jammed = true
	expect(not Combat.preview(g, shooter, target).ok, "a jammed weapon can't shoot")
	shooter.weapon.jammed = false
	shooter.weapon.ammo = 0
	expect(Combat.preview(g, shooter, target).reason.contains("empty"), "an empty weapon can't shoot")
	shooter.weapon.ammo = 24

	# Killing
	target.hp = 1
	target.max_hp = 8
	var killed := target.take_damage(5)
	expect(killed and target.hp == 0 and not target.is_alive(), "damage to 0 HP kills")
	expect(not target.take_damage(3), "a downed unit can't be killed twice")
	g.queue_free()
	shooter.queue_free()
	target.queue_free()


func test_shoot_in_battle() -> void:
	var scene: Node3D = load("res://scenes/battle/battle_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var shoot: BattleAction = scene.actions[0]
	var player: Unit = scene.selected
	expect(player.weapon != null and player.hp == 10, "player units spawn armed with 10 HP")
	expect(scene.living("enemy").size() == 2, "two enemies alive at start")

	# Enter targeting mode
	expect(scene.perform_action(shoot), "Shoot enters targeting mode")
	expect(scene._targeting == shoot and not scene._valid_targets.is_empty(), "at least one enemy is targetable")
	scene.cancel_targeting()
	expect(scene._targeting == null, "targeting can be cancelled")

	# Shoot until both enemies are dead, cheating the budget so we can fire repeatedly.
	Dice.set_seed(3)
	var guard := 0
	while not scene.battle_over and guard < 300:
		guard += 1
		for enemy in scene.living("enemy"):
			var u: Unit = scene.living("player")[0]
			if scene.selected != u:
				scene.select_unit(u)
			u.budget.reset()
			u.weapon.jammed = false
			u.weapon.ammo = u.weapon.mag
			if Combat.preview(scene.grid, u, enemy).ok:
				scene.perform_targeted(shoot, enemy)
				break
			else:
				# Walk the shooter next to the enemy if it can't see it.
				u.place_at(enemy.cell + Vector2i(-1, 0), scene.grid)
	expect(scene.battle_over and scene.living("enemy").is_empty(), "shooting enemies to 0 HP wins the battle")
	expect(scene.hud.log_text().contains("Victory"), "victory is announced in the log")
	expect(not scene.perform_action(shoot), "no actions after the battle is over")
	scene.queue_free()

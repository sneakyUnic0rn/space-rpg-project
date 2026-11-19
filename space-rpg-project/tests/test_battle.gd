extends SceneTree
## Checks for the grid, pathfinding and movement. Run with:
##   godot --headless --script res://tests/test_battle.gd

var _failures := 0
var _passes := 0


func _initialize() -> void:
	test_pathfinder()
	await test_battle_scene()
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func expect(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)


func test_pathfinder() -> void:
	# Open 10x10 field.
	var open_field := func(c: Vector2i) -> bool: return c.x >= 0 and c.y >= 0 and c.x < 10 and c.y < 10
	var reach := GridPathfinder.reachable(Vector2i(5, 5), 3.0, open_field)
	expect(reach["costs"].has(Vector2i(8, 5)), "3 straight tiles reachable with 3 movement")
	expect(not reach["costs"].has(Vector2i(9, 5)), "4 straight tiles not reachable with 3 movement")
	expect(is_equal_approx(reach["costs"][Vector2i(7, 7)], 3.0), "2 diagonal steps cost 3.0")
	expect(not reach["costs"].has(Vector2i(8, 8)), "3 diagonal steps (4.5) out of range")
	var path := GridPathfinder.path_to(reach, Vector2i(8, 5))
	expect(path == [Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5)], "straight path is correct and excludes the start")

	# Wall in the way: column x=3 blocked except at y=0.
	var walled := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < 7 and c.y < 7 and not (c.x == 3 and c.y > 0)
	reach = GridPathfinder.reachable(Vector2i(1, 3), 20.0, walled)
	path = GridPathfinder.path_to(reach, Vector2i(5, 3))
	expect(not path.is_empty() and Vector2i(3, 0) in path, "path goes around the wall through the gap")
	for c in path:
		if not walled.call(c):
			expect(false, "path never enters a wall")
			return
	expect(true, "path never enters a wall")

	# No cutting corners: from (2,1) to (3,0)... diagonal past wall (3,1) must be refused.
	reach = GridPathfinder.reachable(Vector2i(2, 1), 1.5, walled)
	expect(not reach["costs"].has(Vector2i(3, 0)), "can't cut a diagonal past a wall corner")


func test_battle_scene() -> void:
	var scene: Node3D = load("res://scenes/battle/battle_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	expect(scene.grid.width == 12 and scene.grid.height == 12, "test map is 12x12")
	expect(scene.units.size() == 4, "2 player + 2 enemy units spawned")
	expect(scene.selected != null and scene.selected.team == "player", "a player unit starts selected")
	expect(not scene.grid.is_floor(Vector2i(0, 0)), "outer wall is not walkable")
	expect(scene.grid.cover_at(Vector2i(5, 1)) == 1, "crate gives half cover")

	var unit: Unit = scene.selected
	var enemy_cell: Vector2i = scene.grid.spawns["E"][0]
	var blocked := GridPathfinder.reachable(enemy_cell + Vector2i(-2, 0), 6.0, scene._walkable_for_selected)
	expect(not blocked["costs"].has(enemy_cell), "can't move onto another unit's tile")
	var start := unit.cell
	var target := start + Vector2i(0, 3)  # straight down, open floor
	expect(scene.grid.is_floor(target), "test target is a floor tile")
	var moved: bool = await scene.try_move_to(target)
	expect(moved, "unit accepts a move to a reachable tile")
	expect(unit.cell == target, "unit's cell updated after moving")
	expect(unit.position.distance_to(scene.grid.cell_to_world(target)) < 0.01, "unit physically arrived on the tile")

	var wall_move: bool = await scene.try_move_to(Vector2i(0, 0))
	expect(not wall_move and unit.cell == target, "unit refuses to move into a wall")

	var far: bool = await scene.try_move_to(Vector2i(10, 10))
	expect(not far, "unit refuses a tile beyond its movement range")


	scene._select_next()
	expect(scene.selected != unit and scene.selected.team == "player", "Tab switches to the other player unit")
	scene.queue_free()

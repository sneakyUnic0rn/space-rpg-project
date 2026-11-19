extends Node3D
## Step 3.2 test battle: select a unit, see where it can go, click to move.
##   Left click your unit  select it
##   Tab                   select the next player unit
##   Hover a blue tile     preview the route
##   Left click blue tile  move there
## There are no turns yet, so units can move as often as you like.

@onready var grid: BattleGrid = $BattleGrid
@onready var camera_rig: CameraRig = $CameraRig
@onready var units_root: Node3D = $Units
@onready var info_label: Label = $HUD/Info

var units: Array[Unit] = []
var selected: Unit = null
var _reach := {}
var _hover_cell := Vector2i(-1, -1)


func _ready() -> void:
	_setup_environment()
	grid.build()

	for cell in grid.spawns["P"]:
		_spawn_unit("player", cell)
	for cell in grid.spawns["E"]:
		_spawn_unit("enemy", cell)

	camera_rig.bounds = AABB(Vector3.ZERO, Vector3(grid.width, 0, grid.height))
	camera_rig.focus_on(grid.center())

	var players := _player_units()
	if not players.is_empty():
		select_unit(players[0])
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_hover(_cell_under_mouse(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click(_cell_under_mouse(event.position))
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_select_next()


# --- Actions (public so tests and, later, the turn system can call them) ---

func select_unit(unit: Unit) -> void:
	if selected:
		selected.set_selected(false)
	selected = unit
	if selected:
		selected.set_selected(true)
	_refresh_reach()
	_update_info()


func try_move_to(cell: Vector2i) -> bool:
	if selected == null or selected.is_moving or cell == selected.cell:
		return false
	var path := GridPathfinder.path_to(_reach, cell)
	if path.is_empty():
		return false
	grid.clear_reachable()
	grid.clear_path()
	await selected.move_along(path, grid)
	_refresh_reach()
	_update_info()
	return true


func unit_at(cell: Vector2i) -> Unit:
	for u in units:
		if u.cell == cell:
			return u
	return null


# --- Internals -------------------------------------------------------------

func _spawn_unit(team: String, cell: Vector2i) -> void:
	var u := Unit.new()
	u.team = team
	u.name = "%s_%d" % [team.capitalize(), units.size() + 1]
	units_root.add_child(u)
	u.place_at(cell, grid)
	if team == "enemy":
		u.rotation.y = PI  # face the players
	units.append(u)


func _player_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.team == "player":
			result.append(u)
	return result


func _select_next() -> void:
	var players := _player_units()
	if players.is_empty():
		return
	var i := players.find(selected)
	select_unit(players[(i + 1) % players.size()])


func _walkable_for_selected(cell: Vector2i) -> bool:
	if not grid.is_floor(cell):
		return false
	var other := unit_at(cell)
	return other == null or other == selected


func _refresh_reach() -> void:
	grid.clear_path()
	if selected == null:
		_reach = {}
		grid.clear_reachable()
		return
	_reach = GridPathfinder.reachable(selected.cell, selected.move_range, _walkable_for_selected)
	var cells: Array = _reach["costs"].keys()
	cells.erase(selected.cell)
	grid.show_reachable(cells)


func _on_hover(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	if selected and not selected.is_moving and _reach.get("costs", {}).has(cell) and cell != selected.cell:
		grid.show_path(GridPathfinder.path_to(_reach, cell))
	else:
		grid.clear_path()
	_update_info()


func _on_click(cell: Vector2i) -> void:
	if selected and selected.is_moving:
		return
	var clicked := unit_at(cell)
	if clicked and clicked.team == "player":
		select_unit(clicked)
	else:
		try_move_to(cell)


## Where the mouse ray hits the floor (y = 0), as a grid cell.
func _cell_under_mouse(mouse_pos: Vector2) -> Vector2i:
	var cam := camera_rig.camera
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
		cam.project_ray_origin(mouse_pos), cam.project_ray_normal(mouse_pos))
	if hit == null:
		return Vector2i(-1, -1)
	return grid.world_to_cell(hit)


func _update_info() -> void:
	var lines := ["Step 3.2: grid + movement   |   WASD pan, wheel zoom, Q/E rotate, Tab next unit"]
	if selected:
		var s := "Selected: %s  (move %.0f tiles)" % [selected.name, selected.move_range]
		if _reach.get("costs", {}).has(_hover_cell) and _hover_cell != selected.cell:
			s += "   |   route cost %.1f" % _reach["costs"][_hover_cell]
		lines.append(s)
	if grid.is_inside(_hover_cell):
		var cover: String = ["no cover", "half cover", "full cover"][grid.cover_at(_hover_cell)]
		lines.append("Tile %s: %s" % [_hover_cell, cover])
	info_label.text = "\n".join(lines)


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

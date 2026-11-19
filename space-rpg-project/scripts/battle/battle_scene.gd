extends Node3D
## Test battle: grid movement, turns and shooting.
##   Left click your unit   select it          Tab        next unit with something left to do
##   Hover a blue tile      preview route      1-6        use an action
##   Left click blue tile   move there         Enter      end turn
##   Shoot: click a red-ringed enemy (hover shows hit chance). Right click / Esc cancels.
## Enemies don't act yet (step 3.5).

const ENEMY_PHASE_TIME := 0.8  # seconds the placeholder enemy turn lasts

@onready var grid: BattleGrid = $BattleGrid
@onready var camera_rig: CameraRig = $CameraRig
@onready var units_root: Node3D = $Units
@onready var hud: BattleHUD = $HUD/BattleHUD

var units: Array[Unit] = []
var selected: Unit = null
var actions: Array[BattleAction] = ActionLibrary.default_actions()
var round_number := 1
var is_player_phase := true
var battle_over := false

var _reach := {}
var _hover_cell := Vector2i(-1, -1)
var _targeting: BattleAction = null  # set while choosing a target
var _valid_targets: Array[Unit] = []


func _ready() -> void:
	_setup_environment()
	grid.build()

	# Test loadouts. Real characters come from character creation later.
	var player_weapons := ["Assault Rifle", "Pump Shotgun"]
	var enemy_weapons := ["Service Revolver", "Submachine Gun"]
	for i in grid.spawns["P"].size():
		_spawn_unit("player", grid.spawns["P"][i], player_weapons[i % player_weapons.size()], "Composite Vest")
	for i in grid.spawns["E"].size():
		_spawn_unit("enemy", grid.spawns["E"][i], enemy_weapons[i % enemy_weapons.size()], "Padded Flight Suit")

	camera_rig.bounds = AABB(Vector3.ZERO, Vector3(grid.width, 0, grid.height))
	camera_rig.focus_on(grid.center())

	hud.set_actions(actions)
	hud.action_pressed.connect(func(a): perform_action(a))
	hud.end_turn_pressed.connect(func(): end_player_turn())

	hud.log_line("— Round 1: your turn —", "#ffd24d")
	_select_first_ready()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_hover(_cell_under_mouse(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(_cell_under_mouse(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_select_next()
			KEY_ENTER, KEY_KP_ENTER:
				end_player_turn()
			KEY_ESCAPE:
				cancel_targeting()
			_:
				var index: int = event.keycode - KEY_1
				if index >= 0 and index < actions.size():
					perform_action(actions[index])


# --- Public actions (also used by tests and, later, the AI) -------------------

func select_unit(unit: Unit) -> void:
	cancel_targeting()
	if selected:
		selected.set_selected(false)
	selected = unit
	if selected:
		selected.set_selected(true)
	_refresh_reach()
	_refresh_ui()


func try_move_to(cell: Vector2i) -> bool:
	if not _can_command() or _targeting or not selected.budget.can_move() or cell == selected.cell:
		return false
	var path := GridPathfinder.path_to(_reach, cell)
	if path.is_empty():
		return false
	selected.budget.use_move()
	grid.clear_reachable()
	grid.clear_path()
	_refresh_ui()
	await selected.move_along(path, grid)
	_after_unit_acted()
	return true


## Use an action. Actions that need a target start targeting mode instead.
func perform_action(action: BattleAction) -> bool:
	if not _can_command():
		return false
	var reason := _why_not(action)
	if reason != "":
		hud.log_line(reason, "#ff8080")
		return false
	if action.needs_target:
		_start_targeting(action)
		return true
	_execute(action, null)
	return true


## Use a targeted action on a specific unit (what a click in targeting mode does).
func perform_targeted(action: BattleAction, target: Unit) -> bool:
	if not _can_command():
		return false
	var reason := _why_not(action)
	if reason == "":
		var p := Combat.preview(grid, selected, target)
		reason = "" if p.ok else p.reason
	if reason != "":
		hud.log_line(reason, "#ff8080")
		return false
	cancel_targeting()
	selected.face(target.position)
	_execute(action, target)
	_show_tracer(selected, target)
	return true


func cancel_targeting() -> void:
	if _targeting == null:
		return
	_targeting = null
	for u in _valid_targets:
		u.set_targetable(false)
	_valid_targets.clear()
	_refresh_reach()
	_refresh_ui()


func end_player_turn() -> void:
	if not is_player_phase or battle_over:
		return
	is_player_phase = false
	select_unit(null)
	hud.log_line("— Enemy turn —", "#ff8080")
	_refresh_ui()

	# Placeholder: enemies just wait. Real AI arrives in step 3.5.
	await get_tree().create_timer(ENEMY_PHASE_TIME).timeout
	hud.log_line("Enemies hold their position.")

	round_number += 1
	for u in units:
		u.budget.reset()
		u.aim_bonus = 0
		u.set_exhausted(false)
	is_player_phase = true
	hud.log_line("— Round %d: your turn —" % round_number, "#ffd24d")
	_select_first_ready()


func unit_at(cell: Vector2i) -> Unit:
	for u in units:
		if u.cell == cell and u.is_alive():
			return u
	return null


func living(team: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if u.team == team and u.is_alive():
			result.append(u)
	return result


# --- Internals -------------------------------------------------------------

func _can_command() -> bool:
	return is_player_phase and not battle_over and selected != null and not selected.is_moving


func _why_not(action: BattleAction) -> String:
	var reason := selected.budget.why_not(action)
	return reason if reason != "" else action.blocked_reason(selected)


func _execute(action: BattleAction, target: Unit) -> void:
	selected.budget.spend(action)
	var result: Dictionary = action.effect.call(selected, target, self)
	hud.log_line(result["text"])
	if result.get("refund", 0) > 0:
		selected.budget.refund(result["refund"])
	_check_battle_end()
	_after_unit_acted()


func _start_targeting(action: BattleAction) -> void:
	_valid_targets.clear()
	var blocked := []
	for enemy in living("enemy"):
		var p := Combat.preview(grid, selected, enemy)
		if p.ok:
			_valid_targets.append(enemy)
		else:
			blocked.append("%s: %s" % [enemy.name, p.reason])
	if _valid_targets.is_empty():
		hud.log_line("No targets. " + "; ".join(blocked), "#ff8080")
		return
	_targeting = action
	for u in _valid_targets:
		u.set_targetable(true)
	grid.clear_reachable()
	grid.clear_path()
	hud.log_line("Choose a target (right-click to cancel).", "#999999")
	_refresh_ui()


func _check_battle_end() -> void:
	if battle_over:
		return
	if living("enemy").is_empty():
		battle_over = true
		hud.log_line("★ Victory! All enemies are down. ★", "#9f9")
	elif living("player").is_empty():
		battle_over = true
		hud.log_line("Defeat. Your squad is down.", "#ff6060")


## After any move/action: update visuals, and move on if the unit is done.
func _after_unit_acted() -> void:
	if selected == null or battle_over:
		_refresh_ui()
		return
	if selected.budget.is_exhausted():
		selected.set_exhausted(true)
		if _ready_player_units().is_empty():
			hud.log_line("All units done.")
			end_player_turn()
			return
		_select_first_ready()
		return
	_refresh_reach()
	_refresh_ui()


func _spawn_unit(team: String, cell: Vector2i, weapon_name: String, armour_item: String) -> void:
	var u := Unit.new()
	u.team = team
	u.name = "%s_%d" % [team.capitalize(), units.size() + 1]
	if team == "player":
		# Test character: Firearms = DEX 60 / 2 + 30 = 60, HP = (50 + 50) / 10 = 10
		u.stats.attributes = {"STR": 50, "DEX": 60, "CON": 50, "INT": 45, "WIS": 55, "CHA": 40}
		u.stats.skill_points = {"Firearms": 30, "Perception": 20}
	else:
		# Test grunt: Firearms = DEX 50 / 2 + 20 = 45, HP = (40 + 40) / 10 = 8
		u.stats.attributes = {"STR": 40, "DEX": 50, "CON": 40, "INT": 40, "WIS": 40, "CHA": 40}
		u.stats.skill_points = {"Firearms": 20}
	units_root.add_child(u)
	u.equip(weapon_name, armour_item)
	u.place_at(cell, grid)
	if team == "enemy":
		u.rotation.y = PI
	units.append(u)


func _player_units() -> Array[Unit]:
	return living("player")


func _ready_player_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for u in _player_units():
		if not u.budget.is_exhausted():
			result.append(u)
	return result


func _select_first_ready() -> void:
	var ready_units := _ready_player_units()
	select_unit(ready_units[0] if not ready_units.is_empty() else null)


func _select_next() -> void:
	var ready_units := _ready_player_units()
	if ready_units.is_empty() or not is_player_phase:
		return
	var i := ready_units.find(selected)
	select_unit(ready_units[(i + 1) % ready_units.size()])


func _walkable_for_selected(cell: Vector2i) -> bool:
	if not grid.is_floor(cell):
		return false
	var other := unit_at(cell)
	return other == null or other == selected


func _refresh_reach() -> void:
	grid.clear_path()
	if selected == null or not selected.budget.can_move() or not is_player_phase or _targeting or battle_over:
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
	if _can_command() and not _targeting and _reach.get("costs", {}).has(cell) and cell != selected.cell:
		grid.show_path(GridPathfinder.path_to(_reach, cell))
	else:
		grid.clear_path()
	_refresh_ui()


func _on_click(cell: Vector2i) -> void:
	if not is_player_phase or battle_over or (selected and selected.is_moving):
		return
	var clicked := unit_at(cell)
	if _targeting:
		if clicked and clicked in _valid_targets:
			perform_targeted(_targeting, clicked)
		return
	if clicked and clicked.team == "player":
		if clicked.budget.is_exhausted():
			hud.log_line("%s has nothing left this turn." % clicked.name, "#999999")
		else:
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


func _refresh_ui() -> void:
	hud.refresh(selected, is_player_phase and not battle_over)
	var lines := ["Round %d  |  %s" % [round_number, "Battle over" if battle_over else ("Your turn" if is_player_phase else "Enemy turn")],
		"WASD pan, wheel zoom, Q/E rotate, Tab next unit, 1-6 actions, Enter end turn"]
	var hovered := unit_at(_hover_cell)
	if _targeting and selected and hovered and hovered.team == "enemy":
		var p := Combat.preview(grid, selected, hovered)
		if p.ok:
			var mods: String = ", ".join(p.notes) if not p.notes.is_empty() else "no modifiers"
			lines.append("Shoot %s: %d%% to hit  |  skill %d, %s  |  %.0f m, %s  |  armour %d" % [
				hovered.name, roundi(p.hit_chance * 100), p.skill, mods, p.distance_m,
				selected.weapon.damage_dice(p.distance_m), selected.weapon.effective_armour(hovered.armour)])
		else:
			lines.append("Can't shoot %s: %s" % [hovered.name, p.reason])
	elif selected and _reach.get("costs", {}).has(_hover_cell) and _hover_cell != selected.cell:
		lines.append("Route cost %.1f / %.0f tiles" % [_reach["costs"][_hover_cell], selected.move_range])
	if grid.is_inside(_hover_cell) and not _targeting:
		var cover: String = ["no cover", "half cover", "full cover"][grid.cover_at(_hover_cell)]
		lines.append("Tile %s: %s" % [_hover_cell, cover])
	hud.info_label.text = "\n".join(lines)


func _show_tracer(from: Unit, to: Unit) -> void:
	var a := from.position + Vector3(0, 1.2, 0)
	var b := to.position + Vector3(0, 1.0, 0)
	var mesh := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	add_child(line)
	get_tree().create_timer(0.25).timeout.connect(line.queue_free)


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

class_name BattleGrid
extends Node3D
## The battle map. Built from a simple text layout you can edit in the Inspector:
##   .  floor
##   #  full cover (wall, blocks movement)
##   h  half cover (low crate, blocks movement for now)
##   P  player unit start (floor)
##   E  enemy unit start (floor)

const TILE := 1.0

@export_multiline var layout := """
############
#....h.....#
#.P..h..E..#
#..........#
#..##...h..#
#..##...h..#
#..........#
#.h....##..#
#.h....##..#
#....P.....#
#.......E..#
############
"""

var width := 0
var height := 0
var spawns := {"P": [], "E": []}

var _cells := {}  # Vector2i -> "." / "#" / "h"
var _reach_root := Node3D.new()
var _path_root := Node3D.new()
var _materials := {}


func build() -> void:
	_parse_layout()
	_build_meshes()
	add_child(_reach_root)
	add_child(_path_root)


# --- Queries -------------------------------------------------------------

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain(cell: Vector2i) -> String:
	return _cells.get(cell, "#")


func is_floor(cell: Vector2i) -> bool:
	return terrain(cell) == "."


## 0 = none, 1 = half, 2 = full. Used later for cover bonuses.
func cover_at(cell: Vector2i) -> int:
	match terrain(cell):
		"h": return 1
		"#": return 2
	return 0


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * TILE, 0.0, (cell.y + 0.5) * TILE)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))


func center() -> Vector3:
	return Vector3(width * TILE / 2.0, 0.0, height * TILE / 2.0)


# --- Highlights ----------------------------------------------------------

func show_reachable(cells: Array) -> void:
	_clear(_reach_root)
	for cell in cells:
		_reach_root.add_child(_tile_marker(cell, Color(0.25, 0.6, 1.0, 0.35), 0.02, 0.9))


func show_path(cells: Array) -> void:
	_clear(_path_root)
	for i in cells.size():
		var is_end: bool = i == cells.size() - 1
		var color := Color(1.0, 0.85, 0.2, 0.9) if is_end else Color(1.0, 0.85, 0.2, 0.55)
		_path_root.add_child(_tile_marker(cells[i], color, 0.03, 0.6 if is_end else 0.3))


func clear_path() -> void:
	_clear(_path_root)


func clear_reachable() -> void:
	_clear(_reach_root)


# --- Building ------------------------------------------------------------

func _parse_layout() -> void:
	var lines: Array[String] = []
	for line in layout.strip_edges().split("\n"):
		lines.append(line.strip_edges())
	height = lines.size()
	width = 0
	for line in lines:
		width = maxi(width, line.length())

	for y in height:
		for x in width:
			var ch := lines[y][x] if x < lines[y].length() else "#"
			var cell := Vector2i(x, y)
			if ch == "P" or ch == "E":
				spawns[ch].append(cell)
				ch = "."
			if ch not in [".", "#", "h"]:
				push_warning("Unknown map symbol '%s' at %s, treating as floor" % [ch, cell])
				ch = "."
			_cells[cell] = ch


func _build_meshes() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(TILE * 0.97, 0.1, TILE * 0.97)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(TILE, 2.0, TILE)
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(TILE * 0.9, 0.8, TILE * 0.9)

	for cell in _cells:
		var pos := cell_to_world(cell)
		var tile := MeshInstance3D.new()
		tile.mesh = floor_mesh
		var checker: bool = (cell.x + cell.y) % 2 == 0
		tile.material_override = _mat(Color(0.32, 0.34, 0.38) if checker else Color(0.28, 0.30, 0.34))
		tile.position = pos + Vector3(0, -0.05, 0)
		add_child(tile)

		match _cells[cell]:
			"#":
				var wall := MeshInstance3D.new()
				wall.mesh = wall_mesh
				wall.material_override = _mat(Color(0.22, 0.24, 0.28))
				wall.position = pos + Vector3(0, 1.0, 0)
				add_child(wall)
			"h":
				var crate := MeshInstance3D.new()
				crate.mesh = crate_mesh
				crate.material_override = _mat(Color(0.42, 0.33, 0.22))
				crate.position = pos + Vector3(0, 0.4, 0)
				add_child(crate)


func _tile_marker(cell: Vector2i, color: Color, y: float, size: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE * size, TILE * size)
	var m := MeshInstance3D.new()
	m.mesh = plane
	m.material_override = _mat(color, true)
	m.position = cell_to_world(cell) + Vector3(0, y, 0)
	return m


func _mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var key := [color, unshaded]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = m
	return _materials[key]


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

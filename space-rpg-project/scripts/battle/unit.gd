class_name Unit
extends Node3D
## One character on the battlefield. For now a grey-box capsule.

signal move_finished

const STEP_TIME := 0.18  # seconds per tile when walking

@export var team := "player"  # "player" or "enemy"
## Movement per turn, in tiles. PLACEHOLDER until movement speed is designed.
@export var move_range := 6.0

var stats := CharacterStats.new()
var cell := Vector2i.ZERO
var is_moving := false

var _ring := MeshInstance3D.new()


func _ready() -> void:
	var color := Color(0.3, 0.6, 1.0) if team == "player" else Color(0.9, 0.3, 0.3)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.mesh = capsule
	body.material_override = _mat(color)
	body.position.y = 0.8
	add_child(body)

	# A small "visor" so you can see which way the unit faces (-Z is forward).
	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.35, 0.12, 0.15)
	visor.mesh = visor_mesh
	visor.material_override = _mat(Color(0.1, 0.1, 0.12))
	visor.position = Vector3(0, 1.3, -0.27)
	add_child(visor)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.48
	_ring.mesh = torus
	_ring.material_override = _mat(Color(1.0, 0.85, 0.2))
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)


func set_selected(selected: bool) -> void:
	_ring.visible = selected


func place_at(new_cell: Vector2i, grid: BattleGrid) -> void:
	cell = new_cell
	position = grid.cell_to_world(new_cell)


## Walk tile by tile along `path`, turning to face each step.
func move_along(path: Array[Vector2i], grid: BattleGrid) -> void:
	if path.is_empty():
		return
	is_moving = true
	cell = path.back()
	var tween := create_tween()
	for step in path:
		var target := grid.cell_to_world(step)
		tween.tween_callback(_face.bind(target))
		tween.tween_property(self, "position", target, STEP_TIME)
	await tween.finished
	is_moving = false
	move_finished.emit()


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, position.y, target.z)
	if position.distance_to(flat) > 0.01:
		look_at(flat, Vector3.UP)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

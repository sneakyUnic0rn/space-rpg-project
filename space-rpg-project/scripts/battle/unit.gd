class_name Unit
extends Node3D
## One character on the battlefield. For now a grey-box capsule.

signal move_finished
signal died

const STEP_TIME := 0.18  # seconds per tile when walking

@export var team := "player"  # "player" or "enemy"
## Movement per turn in tiles (1 tile = 1.5 m, so 6 tiles = 9 m).
## PLACEHOLDER until movement speed is in the design doc.
@export var move_range := 6.0

var stats := CharacterStats.new()
var budget := TurnBudget.new()
var weapon: Weapon = null
var armour_name := "None"
var armour := 0
var hp := 0
var max_hp := 0
var aim_bonus := 0  # bonus dice on the next attack this turn (from Aim)
var cell := Vector2i.ZERO
var is_moving := false

var _ring := MeshInstance3D.new()
var _target_ring := MeshInstance3D.new()
var _label := Label3D.new()
var _body := MeshInstance3D.new()
var _body_mat: StandardMaterial3D
var _base_color: Color


func _ready() -> void:
	var color := Color(0.3, 0.6, 1.0) if team == "player" else Color(0.9, 0.3, 0.3)

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	_body.mesh = capsule
	_base_color = color
	_body_mat = _mat(color)
	_body.material_override = _body_mat
	_body.position.y = 0.8
	add_child(_body)

	# A small "visor" so you can see which way the unit faces (-Z is forward).
	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.35, 0.12, 0.15)
	visor.mesh = visor_mesh
	visor.material_override = _mat(Color(0.1, 0.1, 0.12))
	visor.position = Vector3(0, 0.5, -0.27)
	_body.add_child(visor)

	_ring.mesh = _torus(0.38, 0.48)
	_ring.material_override = _mat(Color(1.0, 0.85, 0.2))
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)

	_target_ring.mesh = _torus(0.42, 0.55)
	_target_ring.material_override = _mat(Color(1.0, 0.25, 0.2))
	_target_ring.position.y = 0.06
	_target_ring.visible = false
	add_child(_target_ring)

	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 28
	_label.outline_size = 8
	_label.position.y = 2.0
	add_child(_label)
	_update_label()


## Give the unit its gear and fill its HP. Call before or after adding to the tree.
func equip(weapon_name: String, armour_item: String) -> void:
	weapon = Weapon.create(weapon_name)
	armour_name = armour_item
	armour = int(DataDB.entry("armour", armour_item).get("value", 0))
	max_hp = stats.max_hp()
	hp = max_hp
	_update_label()


func is_alive() -> bool:
	return hp > 0


## Returns true if this damage took the unit to 0 HP.
func take_damage(amount: int) -> bool:
	if not is_alive() or amount <= 0:
		_flash(Color(0.8, 0.8, 0.8))
		return false
	hp = maxi(0, hp - amount)
	_update_label()
	_flash(Color(1, 1, 1))
	if hp == 0:
		_fall()
		died.emit()
		return true
	return false


func set_selected(selected: bool) -> void:
	_ring.visible = selected


func set_targetable(targetable: bool) -> void:
	_target_ring.visible = targetable


## Grey the unit out when it has nothing left to do this turn.
func set_exhausted(exhausted: bool) -> void:
	if _body_mat and is_alive():
		_body_mat.albedo_color = _base_color.darkened(0.6) if exhausted else _base_color


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
		tween.tween_callback(face.bind(target))
		tween.tween_property(self, "position", target, STEP_TIME)
	await tween.finished
	is_moving = false
	move_finished.emit()


func face(target: Vector3) -> void:
	var flat := Vector3(target.x, position.y, target.z)
	if position.distance_to(flat) > 0.01:
		look_at(flat, Vector3.UP)


func _update_label() -> void:
	if not is_inside_tree():
		return
	if not is_alive() and max_hp > 0:
		_label.text = "DOWN"
		_label.modulate = Color(0.7, 0.7, 0.7)
		return
	_label.text = "%d/%d" % [hp, max_hp]
	var ratio := float(hp) / maxi(1, max_hp)
	_label.modulate = Color(0.5, 1.0, 0.5) if ratio > 0.6 else (Color(1.0, 0.85, 0.3) if ratio > 0.3 else Color(1.0, 0.4, 0.4))


func _flash(color: Color) -> void:
	if _body_mat == null:
		return
	var tween := create_tween()
	_body_mat.albedo_color = color
	tween.tween_property(_body_mat, "albedo_color", _base_color if is_alive() else _base_color.darkened(0.7), 0.25)


func _fall() -> void:
	set_selected(false)
	set_targetable(false)
	var tween := create_tween()
	tween.tween_property(_body, "rotation:x", -PI / 2, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "position:y", 0.3, 0.4)


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

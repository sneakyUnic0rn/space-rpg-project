class_name CameraRig
extends Node3D
## Tactics camera. The rig sits on the ground; the camera orbits around it.
##   WASD / arrow keys  pan
##   Middle mouse drag  pan
##   Mouse wheel        zoom
##   Q / E              rotate 90 degrees

@export var pan_speed := 10.0
@export var zoom_min := 6.0
@export var zoom_max := 28.0
@export var zoom_step := 1.5
@export var pitch_degrees := 55.0
@export var rotate_speed := 8.0

## Limits for panning, set by the battle scene to the map size.
var bounds := AABB(Vector3(-50, 0, -50), Vector3(100, 0, 100))

var camera := Camera3D.new()
var _distance := 13.0
var _target_distance := 13.0
var _target_yaw := deg_to_rad(-45.0)


func _ready() -> void:
	add_child(camera)
	camera.current = true
	rotation.y = _target_yaw
	_update_camera()


func _process(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): input.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): input.x += 1
	if input != Vector2.ZERO:
		_pan(input.normalized() * pan_speed * delta * (_distance / 16.0))

	rotation.y = lerp_angle(rotation.y, _target_yaw, minf(1.0, rotate_speed * delta))
	_distance = lerpf(_distance, _target_distance, minf(1.0, 10.0 * delta))
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(_target_distance - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(_target_distance + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_pan(-event.relative * 0.02 * (_distance / 16.0))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			_target_yaw += PI / 2
		elif event.physical_keycode == KEY_E:
			_target_yaw -= PI / 2


func focus_on(point: Vector3) -> void:
	position = Vector3(point.x, 0, point.z)


## Move relative to where the camera is looking (x = sideways, y = forward/back).
func _pan(amount: Vector2) -> void:
	var right := transform.basis.x
	var back := transform.basis.z
	right.y = 0
	back.y = 0
	position += right.normalized() * amount.x + back.normalized() * amount.y
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z, bounds.position.z, bounds.end.z)


func _update_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0, sin(pitch) * _distance, cos(pitch) * _distance)
	camera.rotation = Vector3(-pitch, 0, 0)

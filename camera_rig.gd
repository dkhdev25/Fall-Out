extends Node3D
# Third-person orbit camera. Follows Greg, mouse to look, crosshair = grapple aim.
# Esc toggles the mouse capture.

@export var target_path: NodePath = ^"../Greg"
@export var distance: float = 38.0
@export var height: float = 6.0
@export var sensitivity: float = 0.005
@export var follow_lerp: float = 6.0

var _yaw: float = 0.0
var _pitch: float = -0.15
var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path)
	var cam := get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		_pitch -= event.relative.y * sensitivity
		_pitch = clamp(_pitch, -1.2, 0.4)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not _target:
		_target = get_node_or_null(target_path)
		if not _target:
			return
	var focus := _target.global_position + Vector3.UP * height
	var b := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var cam_pos := focus + b * Vector3(0.0, 0.0, distance)
	global_position = global_position.lerp(cam_pos, clamp(follow_lerp * delta, 0.0, 1.0))
	look_at(focus, Vector3.UP)

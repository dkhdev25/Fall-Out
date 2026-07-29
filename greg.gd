xtends RigidBody3D
# Wobbly / ragdoll "Greg" whose OWN arms stretch out as grappling hooks.
# Greg-character.obj is one fused static mesh in a T-pose:
#   left hand  ~ (-3.93, 7.12, 0)   right hand ~ (4.04, 7.13, 0)   (arm band y ~ 6.3..8.4)
# We grab the mesh's actual arm vertices and stretch them toward the hook point,
# so the grapple visibly uses Greg's real hand/arm - no invented geometry.
# Everything below is @export so you can tune the feel live in the Inspector.

# ---- Movement ----
@export var max_speed: float = 16.0
@export var accel_gain: float = 3.0
@export var stop_gain: float = 1.5
@export var jump_impulse: float = 1000.0

# ---- Ragdoll / wobble ----
@export var ragdoll: bool = true                 # true = limp & floppy; false = self-righting
@export var upright_stiffness: float = 12000.0
@export var upright_damping: float = 1500.0
@export var body_mass: float = 70.0
@export var gravity_boost: float = 2.2

# ---- Grapple ----
@export var grapple_range: float = 130.0
@export var grapple_stiffness: float = 40.0
@export var grapple_damping: float = 8.0
@export var reel_speed: float = 10.0
@export var min_rope: float = 2.0

# Arm rest data (local space), measured from the model.
const ARM_Y_MIN := 6.3
const ARM_Y_MAX := 8.4
const TORSO_X := 1.1                       # where the arm starts (shoulder)
var _hand := {"l": Vector3(-3.93, 7.12, 0.0), "r": Vector3(4.04, 7.13, 0.0)}

var _mesh: MeshInstance3D
var _rest_mesh: ArrayMesh                   # undeformed Greg
var _surf_arrays: Array = []                # base arrays per surface
var _deform: Array = []                     # per surface: [{idx, side, w}]
var _was_active := false

var _grapple := {
	"l": {"active": false, "anchor": Vector3.ZERO, "length": 0.0},
	"r": {"active": false, "anchor": Vector3.ZERO, "length": 0.0},
}
var _jump_held := false
var _reset_held := false
var _toggle_held := false


func _ready() -> void:
	mass = body_mass
	gravity_scale = gravity_boost
	can_sleep = false
	continuous_cd = true
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 2.5, 0)
	linear_damp = 0.2
	_apply_mode()
	_build_body()


func _apply_mode() -> void:
	angular_damp = 0.1 if ragdoll else 0.5


func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.8
	cap.height = 12.0
	col.shape = cap
	col.position = Vector3(0, 6.0, 0)
	add_child(col)

	_mesh = MeshInstance3D.new()
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.75, 0.65)
	_mesh.material_override = skin
	add_child(_mesh)

	_prepare_deform()
	_mesh.mesh = _rest_mesh


func _prepare_deform() -> void:
	var src := load("res://Greg-character.obj") as ArrayMesh
	_rest_mesh = src
	_surf_arrays.clear()
	_deform.clear()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		_surf_arrays.append(arrays)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var list: Array = []
		for i in verts.size():
			var v: Vector3 = verts[i]
			if v.y < ARM_Y_MIN or v.y > ARM_Y_MAX:
				continue
			if v.x <= -1.0:
				var w: float = clampf((-v.x - TORSO_X) / (-_hand["l"].x - TORSO_X), 0.0, 1.0)
				list.append({"idx": i, "side": "l", "w": w})
			elif v.x >= 1.0:
				var w2: float = clampf((v.x - TORSO_X) / (_hand["r"].x - TORSO_X), 0.0, 1.0)
				list.append({"idx": i, "side": "r", "w": w2})
		_deform.append(list)


func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	_handle_keys()
	_handle_movement(delta, cam)
	_handle_upright()
	_process_arm("l", Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), cam)
	_process_arm("r", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), cam)
	_update_mesh()


func _handle_keys() -> void:
	var r := Input.is_physical_key_pressed(KEY_R)
	if r and not _reset_held:
		var pos := global_position
		global_transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 4.0)
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	_reset_held = r

	var t := Input.is_physical_key_pressed(KEY_G)
	if t and not _toggle_held:
		ragdoll = not ragdoll
		_apply_mode()
	_toggle_held = t


func _handle_movement(_delta: float, cam: Camera3D) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0

	var dir := Vector3.ZERO
	if cam and move != Vector2.ZERO:
		var b := cam.global_transform.basis
		var fwd := -b.z; fwd.y = 0.0; fwd = fwd.normalized()
		var right := b.x; right.y = 0.0; right = right.normalized()
		dir = (fwd * move.y + right * move.x).normalized()

	var hv := linear_velocity; hv.y = 0.0
	if dir != Vector3.ZERO:
		var desired := dir * max_speed
		apply_central_force((desired - hv) * mass * accel_gain)
	else:
		apply_central_force(-hv * mass * stop_gain)

	var sp := Input.is_physical_key_pressed(KEY_SPACE)
	if sp and not _jump_held and _is_grounded():
		apply_central_impulse(Vector3.UP * jump_impulse)
	_jump_held = sp


func _is_grounded() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.5
	var to := from + Vector3.DOWN * 2.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func _handle_upright() -> void:
	if ragdoll:
		return
	var up := global_transform.basis.y
	var axis := up.cross(Vector3.UP)
	var l := axis.length()
	if l > 0.001:
		axis /= l
		var angle := up.angle_to(Vector3.UP)
		var torque := axis * angle * upright_stiffness
		torque -= angular_velocity * upright_damping
		apply_torque(torque)


func _process_arm(key: String, pressed: bool, cam: Camera3D) -> void:
	var g: Dictionary = _grapple[key]
	var hand_world := to_global(_hand[key])

	if pressed and not g.active and cam:
		var space := get_world_3d().direct_space_state
		var from := cam.global_position
		var to := from + (-cam.global_transform.basis.z) * grapple_range
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			g.active = true
			g.anchor = hit.position
			g.length = hand_world.distance_to(g.anchor)
	elif not pressed and g.active:
		g.active = false

	if g.active:
		var anchor: Vector3 = g.anchor - hand_world
		var dist: float = anchor.length()
		if dist > 0.01:
			var dirn: Vector3 = anchor / dist
			g.length = maxf(min_rope, g.length - reel_speed * get_physics_process_delta_time())
			var stretch: float = dist - g.length
			if stretch > 0.0:
				var vel_along: float = linear_velocity.dot(dirn)
				var force_mag: float = stretch * grapple_stiffness * mass - vel_along * grapple_damping * mass
				apply_force(dirn * force_mag, g.anchor - global_position)


func _update_mesh() -> void:
	var any_active: bool = _grapple["l"].active or _grapple["r"].active
	if not any_active:
		if _was_active:
			_mesh.mesh = _rest_mesh
		_was_active = false
		return
	_was_active = true

	# Precompute each active side's local target offset (hand -> hook, in Greg's space).
	var off := {}
	for side in ["l", "r"]:
		if _grapple[side].active:
			off[side] = to_local(_grapple[side].anchor) - _hand[side]

	var am := ArrayMesh.new()
	for s in _surf_arrays.size():
		var arrays: Array = (_surf_arrays[s] as Array).duplicate()
		var base: PackedVector3Array = _surf_arrays[s][Mesh.ARRAY_VERTEX]
		var verts := base.duplicate()
		for d in _deform[s]:
			var side: String = d.side
			if off.has(side):
				verts[d.idx] = base[d.idx] + (off[side] as Vector3) * float(d.w)
		arrays[Mesh.ARRAY_VERTEX] = verts
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.mesh = am

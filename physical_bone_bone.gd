extends PhysicalBone3D

@export var movement_force := 200.0
@export var maximum_speed := 5.0
@export var jump_impulse := 5.0


func _ready() -> void:
	can_sleep = false

	var simulator := get_parent() as PhysicalBoneSimulator3D

	if simulator:
		simulator.physical_bones_start_simulation()
	else:
		push_error("The pelvis must be under a PhysicalBoneSimulator3D.")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	if input.length() > 0.0:
		print("Movement input: ", input)
	var direction := Vector3(input.x, 0.0, input.y)

	if direction.length_squared() == 0.0:
		return

	direction = direction.normalized()

	var horizontal_velocity := Vector3(
		state.linear_velocity.x,
		0.0,
		state.linear_velocity.z
	)

	if horizontal_velocity.length() < maximum_speed:
		state.apply_central_force(direction * movement_force)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		apply_central_impulse(Vector3.UP * jump_impulse)

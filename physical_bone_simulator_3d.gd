extends PhysicalBoneSimulator3D


func _ready() -> void:
	active = true
	physical_bones_start_simulation()

	await get_tree().physics_frame

	print("Ragdoll running: ", is_simulating_physics())

	for child in get_children():
		if child is PhysicalBone3D:
			print(
				child.name,
				" | bone ID: ", child.get_bone_id(),
				" | simulating: ", child.is_simulating_physics()
			)

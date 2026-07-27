extends Node3D
# Builds the playground: lighting, ground, grapple targets, and a crosshair.

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_obstacles()
	_build_crosshair()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.68, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	add_child(_make_box(Vector3(0, -1, 0), Vector3(400, 2, 400), Color(0.32, 0.55, 0.33)))


func _build_obstacles() -> void:
	# Ring of pillars to grapple onto.
	var count := 8
	for i in count:
		var a := TAU * float(i) / float(count)
		var r := 60.0
		var pos := Vector3(cos(a) * r, 15.0, sin(a) * r)
		add_child(_make_box(pos, Vector3(6, 30, 6), Color(0.6, 0.5, 0.45)))

	# A few high floating platforms to swing between.
	var plats := [
		Vector3(0, 35, -40),
		Vector3(35, 45, 25),
		Vector3(-30, 40, 30),
		Vector3(0, 55, 0),
	]
	for p in plats:
		add_child(_make_box(p, Vector3(14, 3, 14), Color(0.5, 0.45, 0.6)))


func _make_box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	return body


func _build_crosshair() -> void:
	var layer := CanvasLayer.new()
	var lbl := Label.new()
	lbl.text = "+"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(lbl)
	add_child(layer)

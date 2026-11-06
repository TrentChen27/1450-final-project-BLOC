extends RigidBody3D

var data: Dictionary
var owner_id := -1
var placed := false
var fallen := false
var center := Vector3.ZERO
var material := StandardMaterial3D.new()
var collision_nodes: Array[CollisionShape3D] = []

func build(info: Dictionary, color: Color) -> void:
	data = info.duplicate(true)
	freeze = true
	mass = float(info.cells.size())
	linear_damp = 0.4
	angular_damp = 0.8
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	material.albedo_color = color
	for cell in info.cells:
		center += Vector3(cell)
	center /= float(info.cells.size())
	for cell in info.cells:
		var dimensions := Vector3.ONE * 0.98
		if info.card != 0:
			dimensions = Vector3(1.8, 0.18, 1.1)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = dimensions
		mesh.mesh = box
		mesh.material_override = material
		mesh.position = Vector3(cell) - center
		add_child(mesh)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		shape.margin = 0.005
		collider.shape = shape
		collider.position = mesh.position
		add_child(collider)
		collision_nodes.append(collider)
	var label := Label3D.new()
	label.text = "#%d / %+d" % [info.id, info.value]
	label.position = Vector3(0, 0.65, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.008
	label.no_depth_test = true
	add_child(label)

func corners() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for collider in collision_nodes:
		var half: Vector3 = collider.shape.size / 2.0
		for x in [-1, 1]:
			for y in [-1, 1]:
				for z in [-1, 1]:
					points.append(collider.global_transform * (half * Vector3(x, y, z)))
	return points

func max_height() -> float:
	var height := -INF
	for point in corners():
		height = maxf(height, point.y)
	return height

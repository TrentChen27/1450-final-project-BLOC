extends RigidBody3D

var data: Dictionary
var owner_id := -1
var placed := false
var fallen := false
var center := Vector3.ZERO
var material := StandardMaterial3D.new()
var collision_nodes: Array[CollisionShape3D] = []

@export var authored_shape := false
@export var unit_cell_scene: PackedScene = preload("res://scenes/blocs/UnitCell.tscn")
@export var card_cell_scene: PackedScene = preload("res://scenes/blocs/CardCell.tscn")

func build(info: Dictionary, color: Color) -> void:
	data = info.duplicate(true)
	freeze = true
	if authored_shape:
		for child in get_children():
			if child is CollisionShape3D:
				collision_nodes.append(child)
	else:
		# Generic fallback supports custom test pieces and debug geometry.
		get_node("SampleCell").free()
		var template := card_cell_scene if info.card != 0 else unit_cell_scene
		for cell in info.cells:
			var collider: CollisionShape3D = template.instantiate()
			collider.position = Vector3(cell)
			add_child(collider)
			collision_nodes.append(collider)
	mass = float(collision_nodes.size())
	for collider in collision_nodes:
		center += collider.position
	center /= float(collision_nodes.size())
	for collider in collision_nodes:
		collider.position -= center
		var mesh: MeshInstance3D = collider.get_node("Mesh")
		mesh.material_override = mesh.material_override.duplicate()
		mesh.material_override.albedo_color = color
	material = collision_nodes[0].get_node("Mesh").material_override
	get_node("ValueLabel").text = "#%d / %+d" % [info.id, info.value]

func set_tint(color: Color) -> void:
	for collider in collision_nodes:
		collider.get_node("Mesh").material_override.albedo_color = color

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

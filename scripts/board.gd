extends Node3D

signal placement_confirmed
signal changed
signal bloc_fell(owner: int, data: Dictionary, action_id: int)
signal defeated(owner: int)
signal instruction(text: String)

const BlocScript = preload("res://scripts/bloc.gd")
const COLORS := [Color("53c5c0"), Color("efbd62"), Color("a399ee"), Color("ec8298")]
@export var stable_duration := 0.75
@export var linear_threshold := 0.08
@export var angular_threshold := 0.08
@export var settle_failsafe := 10.0
@export var sidebar_width := 370.0
var origins: Array[Vector3] = []
var tower_visuals: Array = []
var blocs: Array = []
var fallen_counts: Array[int] = []
var last_actions: Array[int] = []
var action_falls: Array[int] = []
var last_fall_tick: Array[int] = []
var action_serial := 0
var settling := false
var ended := false
var preview = null
var preview_owner := 0
var preview_minimum := -INF
var grid := Vector3i.ZERO
var rotation_basis := Basis.IDENTITY
var valid_preview := false
var preview_reason := ""
var camera: Camera3D
var focus := Vector3(2, 2, 2)
var yaw := 0.75
var pitch := 0.7
var distance := 12.0
var zoom_factor := 1.0
var rotating := false

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172331")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.far = 5000.0
	camera.current = true
	add_child(camera)
	_update_camera()

func setup(count: int) -> void:
	for i in range(count):
		var origin := Vector3((i % 2) * 14, 0, (i / 2) * 14)
		origins.append(origin)
		tower_visuals.append([])
		fallen_counts.append(0)
		last_actions.append(0)
		action_falls.append(0)
		last_fall_tick.append(0)
		var floor_body := StaticBody3D.new()
		floor_body.position = origin + Vector3(2, -0.22, 2)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4, 0.44, 4)
		collision.shape = box
		floor_body.add_child(collision)
		var mesh := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = box.size
		mesh.mesh = box_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = COLORS[i].darkened(0.65)
		mesh.material_override = material
		floor_body.add_child(mesh)
		add_child(floor_body)
		tower_visuals[i].append(floor_body)
		for x in range(5):
			tower_visuals[i].append(_grid_line(origin + Vector3(x, 0.005, 2), Vector3(0.012, 0.012, 4)))
			tower_visuals[i].append(_grid_line(origin + Vector3(2, 0.005, x), Vector3(4, 0.012, 0.012)))
		var label := Label3D.new()
		label.text = "PLAYER %d" % (i + 1)
		label.position = origin + Vector3(2, 0, 5)
		label.font_size = 56
		label.pixel_size = 0.012
		label.modulate = COLORS[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		tower_visuals[i].append(label)
	focus_tower(0)

func _grid_line(at: Vector3, size: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("77939b")
	mesh.material_override = material
	add_child(mesh)
	return mesh

func focus_tower(owner: int) -> void:
	if origins.is_empty():
		return
	focus = origins[owner] + Vector3(2, maxf(1.0, height(owner) * 0.5), 2)
	zoom_factor = 1.0
	rotating = false
	_update_camera()

func _set_tower_visibility(owner: int) -> void:
	# Rendering only: hidden towers still simulate and report late falls.
	for i in range(tower_visuals.size()):
		for visual in tower_visuals[i]:
			visual.visible = owner < 0 or i == owner
	for bloc in blocs:
		bloc.visible = not bloc.fallen and (bloc.placed or bloc == preview) and (owner < 0 or bloc.owner_id == owner)

func _camera_grid_step(forward: bool) -> Vector3i:
	# Use the nearest grid direction; keep W/D perpendicular at diagonal views.
	var direction := Vector3(-sin(yaw), 0, -cos(yaw))
	var step := Vector3i.ZERO
	if absf(direction.x) > absf(direction.z):
		step.x = 1 if direction.x > 0 else -1
	else:
		step.z = 1 if direction.z > 0 else -1
	return step if forward else Vector3i(-step.z, 0, step.x)

func _update_camera() -> void:
	if camera == null:
		return
	distance = maxf(9.0, focus.y * 2.4 + 6.0) * zoom_factor
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(focus)
	# Keep the orbit target centered in the board area, left of the HUD.
	# Move the camera parallel to its image plane without changing its angle.
	var viewport_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var shift := distance * tan(deg_to_rad(camera.fov) * 0.5) * sidebar_width / viewport_height
	camera.position += camera.basis.x * shift

func owned(owner: int) -> Array:
	return blocs.filter(func(b): return b.owner_id == owner and b.placed and not b.fallen)

func score(owner: int) -> int:
	var total := 0
	for bloc in owned(owner):
		if bloc.linear_velocity.y > -0.5:
			total += bloc.data.value
	return total

func height(owner: int) -> float:
	var maximum := 0.0
	for bloc in owned(owner):
		maximum = maxf(maximum, bloc.max_height())
	return maximum

func create_bloc(data: Dictionary):
	var bloc = BlocScript.new()
	bloc.build(data, COLORS[maxi(0, data.get("color_owner", 0)) % 4])
	bloc.collision_layer = 0
	bloc.collision_mask = 0
	add_child(bloc)
	blocs.append(bloc)
	return bloc

func place(item, owner: int, controller: int, minimum_height := -INF) -> bool:
	if ended:
		return false
	preview = create_bloc(item) if item is Dictionary else item
	preview.owner_id = owner
	preview.placed = false
	preview.freeze = true
	preview.sleeping = false
	preview.linear_velocity = Vector3.ZERO
	preview.angular_velocity = Vector3.ZERO
	preview.collision_layer = 0
	preview.collision_mask = 0
	preview_owner = owner
	preview_minimum = minimum_height
	rotation_basis = Basis.IDENTITY
	grid = Vector3i(1, ceili(height(owner)) + 1, 1)
	focus_tower(owner)
	_set_tower_visibility(owner)
	_update_preview()
	instruction.emit("P%d places %s (%+d) on P%d's tower.\nWASD camera-relative · R/F height · Q/E, Z/X, C/V rotate · Space release · Left-drag orbit" % [controller + 1, preview.data.shape, preview.data.value, owner + 1])
	await placement_confirmed
	if ended:
		return false
	var released = preview
	preview = null
	if not begin_action(owner):
		return false
	released.material.albedo_color = COLORS[owner]
	released.collision_layer = 1
	released.collision_mask = 1
	released.placed = true
	released.freeze = false
	released.sleeping = false
	await settle(owner)
	_set_tower_visibility(-1)
	changed.emit()
	return not ended

func confirm_placement() -> void:
	if preview != null and not settling and not ended:
		_update_preview()
		if valid_preview:
			placement_confirmed.emit()

func _update_preview() -> void:
	if preview == null:
		return
	preview.basis = rotation_basis
	preview.position = origins[preview_owner] + Vector3(grid) + Vector3.ONE * 0.5 + rotation_basis * preview.center
	valid_preview = placement_valid(preview, preview_owner, preview_minimum)
	preview.material.albedo_color = Color("56e6b2") if valid_preview else Color("ef6565")
	focus = origins[preview_owner] + Vector3(2, maxf(1.0, maxf(height(preview_owner), preview.max_height()) * 0.5), 2)
	_update_camera()

func placement_valid(bloc, owner: int, minimum_height := -INF) -> bool:
	preview_reason = "Ready — Space to release"
	for point in bloc.corners():
		var relative: Vector3 = point - origins[owner]
		if relative.x < -0.001 or relative.x > 4.001 or relative.z < -0.001 or relative.z > 4.001 or relative.y < -0.001:
			preview_reason = "Keep the entire piece above and inside the 4 × 4 mat"
			return false
	if bloc.max_height() <= minimum_height + 0.01:
		preview_reason = "Collapse: some part must be higher than its former top"
		return false
	for collider in bloc.collision_nodes:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = collider.global_transform
		query.exclude = [bloc.get_rid()]
		query.collision_mask = 1
		query.margin = 0.0
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			preview_reason = "Overlaps a solid piece — move or raise it"
			return false
	return true

func remove_bloc(bloc) -> bool:
	if ended or bloc.fallen or not bloc.placed:
		return false
	var owner: int = bloc.owner_id
	if not begin_action(owner):
		return false
	bloc.placed = false
	bloc.freeze = true
	bloc.collision_layer = 0
	bloc.collision_mask = 0
	bloc.position.y = -100.0
	# Removing support must wake bodies that previously went to sleep.
	for other in owned(owner):
		other.sleeping = false
	await settle(owner)
	changed.emit()
	return not ended

func begin_action(owner: int) -> bool:
	# Account for the previous physics step before assigning a new action.
	scan_falls()
	if ended:
		return false
	action_serial += 1
	last_actions[owner] = action_serial
	action_falls[owner] = 0
	last_fall_tick[owner] = 0
	return true

func settle(owner: int) -> void:
	settling = true
	instruction.emit("P%d tower settling… controls locked" % (owner + 1))
	var stable := 0.0
	var duration := 0.0
	var previous_falls: int = fallen_counts[owner]
	while not ended and duration < settle_failsafe:
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		duration += delta
		scan_falls()
		var slow := true
		for bloc in owned(owner):
			if not bloc.sleeping and (bloc.linear_velocity.length() > linear_threshold or bloc.angular_velocity.length() > angular_threshold):
				slow = false
		if previous_falls != fallen_counts[owner]:
			slow = false
			previous_falls = fallen_counts[owner]
		stable = stable + delta if slow else 0.0
		if stable >= stable_duration:
			break
	if duration >= settle_failsafe:
		scan_falls()
		for bloc in owned(owner):
			bloc.linear_velocity = Vector3.ZERO
			bloc.angular_velocity = Vector3.ZERO
			bloc.sleeping = true
	settling = false
	changed.emit()

func scan_falls() -> void:
	if ended:
		return
	for bloc in blocs:
		if not bloc.placed or bloc.fallen:
			continue
		var owner: int = bloc.owner_id
		var relative: Vector3 = bloc.position - origins[owner]
		if relative.y < -0.3 or relative.x < -3.0 or relative.x > 7.0 or relative.z < -3.0 or relative.z > 7.0:
			bloc.fallen = true
			bloc.placed = false
			bloc.freeze = true
			bloc.hide()
			bloc.collision_layer = 0
			bloc.collision_mask = 0
			fallen_counts[owner] += 1
			action_falls[owner] += 1
			bloc_fell.emit(owner, bloc.data, last_actions[owner])
			changed.emit()
			if action_falls[owner] >= 4:
				ended = true
				defeated.emit(owner)
				return

func _physics_process(_delta: float) -> void:
	scan_falls()
	if preview != null:
		_update_preview()

func _input(event: InputEvent) -> void:
	# GUI controls may consume the release after a drag crosses the sidebar.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		rotating = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		rotating = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			rotating = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_factor = maxf(0.4, zoom_factor * 0.9)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_factor = minf(4.0, zoom_factor / 0.9)
		_update_camera()
	if event is InputEventMouseMotion and rotating:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			rotating = false
			return
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.008, 0.15, 1.4)
		_update_camera()
	if preview == null or settling or ended or not event is InputEventKey or not event.pressed:
		return
	match event.physical_keycode:
		KEY_W: grid += _camera_grid_step(true)
		KEY_S: grid -= _camera_grid_step(true)
		KEY_A: grid -= _camera_grid_step(false)
		KEY_D: grid += _camera_grid_step(false)
		KEY_R: grid.y += 1
		KEY_F: grid.y = maxi(0, grid.y - 1)
		KEY_Q: rotation_basis = Basis(Vector3.UP, PI / 2) * rotation_basis
		KEY_E: rotation_basis = Basis(Vector3.UP, -PI / 2) * rotation_basis
		KEY_Z: rotation_basis = Basis(Vector3.RIGHT, PI / 2) * rotation_basis
		KEY_X: rotation_basis = Basis(Vector3.RIGHT, -PI / 2) * rotation_basis
		KEY_C: rotation_basis = Basis(Vector3.BACK, PI / 2) * rotation_basis
		KEY_V: rotation_basis = Basis(Vector3.BACK, -PI / 2) * rotation_basis
		KEY_SPACE:
			if not event.echo:
				confirm_placement()
	_update_preview()

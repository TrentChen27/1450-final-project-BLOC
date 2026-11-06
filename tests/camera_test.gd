extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_checks")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_checks() -> void:
	root.size = Vector2i(1280, 800)
	var board = load("res://scripts/board.gd").new()
	root.add_child(board)
	board.setup(3)
	await physics_frame
	var other = board.create_bloc({"id": 99, "value": 1, "shape": "other tower", "cells": [Vector3i.ZERO], "card": 0})
	other.owner_id = 0
	other.placed = true
	other.position = Vector3(1, 0.5, 1)
	board.place({"id": 100, "value": -2, "shape": "card", "cells": [Vector3i.ZERO], "card": 8}, 2, 0)
	check(is_equal_approx(board.focus.x, board.origins[2].x + 2.0) and is_equal_approx(board.focus.z, board.origins[2].z + 2.0), "Placement focuses destination tower, not controller")
	check(not other.visible, "Other players' pieces are hidden during placement")
	var other_label = board.get_children().filter(func(node): return node is Label3D and node.text == "PLAYER 1")[0]
	check(not other_label.visible, "Other players' mats and labels are hidden during placement")
	var projected: Vector2 = board.camera.unproject_position(board.focus)
	check(absf(projected.x - (1280.0 - 370.0) / 2.0) < 2.0, "Tower centered in usable area beside sidebar")
	var original_yaw: float = board.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	board._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(60, 20)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	board._unhandled_input(motion)
	check(board.yaw != original_yaw, "Left drag orbits camera")
	var after_drag: float = board.yaw
	if board.has_method("_input"):
		press.pressed = false
		board._input(press)
	motion.button_mask = 0
	board._unhandled_input(motion)
	check(not board.rotating and board.yaw == after_drag, "Release over UI cannot leave camera dragging")
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	board._unhandled_input(press)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	board._unhandled_input(motion)
	check(board.yaw == after_drag, "Right button no longer starts orbit")
	var key := InputEventKey.new()
	key.pressed = true
	for orientation in range(4):
		board.yaw = orientation * PI / 2.0
		board._update_camera()
		var start := Vector3i(1, 2, 1)
		board.grid = start
		key.physical_keycode = KEY_W
		board._unhandled_input(key)
		var forward_step: Vector3i = board.grid - start
		var expected: Vector3i = [Vector3i(0,0,-1), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(1,0,0)][orientation]
		check(forward_step == expected, "W follows camera quadrant %d" % orientation)
		board.grid = start
		key.physical_keycode = KEY_D
		board._unhandled_input(key)
		check(Vector3(board.grid - start).dot(board.camera.basis.x) > 0.9, "D moves screen-right in quadrant %d" % orientation)
		key.physical_keycode = KEY_A
		board._unhandled_input(key)
		check(board.grid == start, "A reverses D")
		key.physical_keycode = KEY_W
		board._unhandled_input(key)
		key.physical_keycode = KEY_S
		board._unhandled_input(key)
		check(board.grid == start, "S reverses W")
	board.grid.y = 25
	board._update_preview()
	var tip: Vector2 = board.camera.unproject_position(board.preview.position)
	check(tip.y > 100.0 and tip.y < 750.0 and tip.x < 910.0, "Raised preview remains visible with target tower")
	board.grid = Vector3i(1, 1, 1)
	board._update_preview()
	board.confirm_placement()
	while board.settling:
		await physics_frame
	check(other.visible and other_label.visible, "Other towers return after placement settles")
	print("%s camera: destination focus, isolated tower, camera-relative WASD, sidebar framing, left drag, release, tall preview" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

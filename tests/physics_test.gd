extends SceneTree
const BoardScript = preload("res://scripts/board.gd")
const Catalog = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0
var board
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func wait_settle() -> void:
	var frames := 0
	while board.settling and frames < 900:
		await physics_frame
		frames += 1
	check(not board.settling, "Physics must finish settling within failsafe")
func data(id: int) -> Dictionary:
	return {"id": id, "value": 1, "shape": "test cube", "cells": [Vector3i.ZERO], "card": 0}
func run_tests() -> void:
	board = BoardScript.new()
	root.add_child(board)
	board.setup(2)
	await physics_frame
	board.place(data(1), 0, 0)
	await physics_frame
	board.grid = Vector3i(0, 0, 0)
	board._update_preview()
	check(board.valid_preview, "Empty mat grid placement must be valid")
	board.grid.x = -1
	board._update_preview()
	check(not board.valid_preview, "Footprint boundary must reject out-of-bounds")
	board.grid.x = 0
	board._update_preview()
	board.confirm_placement()
	await wait_settle()
	check(board.owned(0).size() == 1 and board.score(0) == 1, "Confirmed body settles and scores")
	var bottom = board.owned(0)[0]
	check(absf(bottom.position.y - 0.49) < 0.1, "Body rests on mat")
	board.place(data(2), 0, 0)
	await physics_frame
	board.grid = Vector3i.ZERO
	board._update_preview()
	check(not board.valid_preview, "Overlap must be rejected")
	board.grid.y = 1
	board._update_preview()
	check(board.valid_preview, "Non-overlapping stack is legal")
	board.confirm_placement()
	await wait_settle()
	var top = board.owned(0)[1]
	check(top.position.y > 1.3, "Second body rests on first")
	board.remove_bloc(bottom)
	await wait_settle()
	check(not bottom.placed and board.score(0) == 1, "Held body stops scoring")
	check(top.position.y < 0.7, "Support removal wakes the supported body")
	board.place(bottom, 0, 0, 2.0)
	await physics_frame
	board.grid = Vector3i(2, 0, 2)
	board._update_preview()
	check(not board.valid_preview, "Collapse minimum height enforced")
	board.grid.y = 3
	board._update_preview()
	check(board.valid_preview, "Collapse can place higher")
	board.confirm_placement()
	await wait_settle()
	board.begin_action(1)
	for i in range(3):
		var fallen = board.create_bloc(data(20 + i))
		fallen.owner_id = 1
		fallen.placed = true
		fallen.position = board.origins[1] + Vector3(2, -1, 2)
	board.scan_falls()
	check(board.action_falls[1] == 3 and not board.ended, "Three falls do not defeat")
	var late = board.create_bloc(data(23))
	late.owner_id = 1
	late.placed = true
	late.position = board.origins[1] + Vector3(2, -1, 2)
	board.begin_action(1)
	check(board.ended and board.action_falls[1] == 4, "Late fourth fall must be scanned before a new action resets the count")
	print("%s physics: %d checks / placement, bounds, overlap, gravity, support removal, Collapse height, late falls" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

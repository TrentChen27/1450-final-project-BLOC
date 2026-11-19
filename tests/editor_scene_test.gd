extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_checks")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	# Before entering the tree: these must be saved, not created by _ready.
	var hud = scene.get_node_or_null("HUD")
	var camera = scene.get_node_or_null("Board/Camera3D")
	var tower = scene.get_node_or_null("Board/Towers/Player1")
	check(hud != null, "HUD must exist in the saved scene before Play")
	check(camera != null, "Camera must be editable before Play")
	check(tower != null, "Tower must be visible in the saved scene before Play")
	check(scene.has_node("Board/EditorBlocPreviews"), "Bloc examples must be visible before Play")
	if failures > 0:
		scene.free()
		quit(1)
		return
	camera.fov = 62.0
	var title = hud.get_node("%Title")
	title.text = "Inspector edited title"
	var start_button = hud.get_node("Root/MainMenu").get_node("%Options").get_child(0)
	start_button.text = "Edited two-player button"
	var foundation = tower.get_node("Foundation/Mesh")
	var edited_material := StandardMaterial3D.new()
	edited_material.roughness = 0.23
	foundation.material_override = edited_material
	var towers = scene.get_node("Board/Towers")
	towers.position = Vector3(10, 0, 3)
	var third = load("res://scenes/board/Tower.tscn").instantiate()
	third.name = "AuthoredThirdTower"
	third.position = Vector3(0, 0, 14)
	var third_material := StandardMaterial3D.new()
	third_material.albedo_color = Color.MAGENTA
	third.get_node("Foundation/Mesh").material_override = third_material
	towers.add_child(third)
	root.add_child(scene)
	await process_frame
	check(scene.hud == hud, "Startup reuses the saved HUD")
	check(not scene.board.has_node("EditorBlocPreviews") and scene.board.blocs.is_empty(), "Editor examples must not become gameplay pieces")
	check(scene.board.camera == camera and is_equal_approx(camera.fov, 62.0), "Startup preserves camera Inspector settings")
	check(title.text == "Inspector edited title", "Startup preserves UI text edits")
	check(hud.options.get_child(0) == start_button and start_button.text == "Edited two-player button", "Setup uses saved menu buttons rather than replacing them")
	scene.hud.choose(4)
	await process_frame
	check(scene.board.get_node("Towers").get_child_count() == 4, "Four-player setup uses exactly four towers")
	check(scene.board.get_node("Towers/Player1") == tower, "Setup reuses saved tower")
	check(is_equal_approx(foundation.material_override.roughness, 0.23), "Tower setup preserves edited material")
	check(scene.board.origins[0] == Vector3(10, 0, 3), "Moving the tower group also moves placement origins")
	check(third.get_node("Foundation/Mesh").material_override.albedo_color == Color.MAGENTA, "Authored extra tower colors survive setup")
	check(scene.board.find_children("*", "Camera3D", true, false).size() == 1, "Startup does not duplicate the saved camera")
	check(scene.board.find_children("*", "StaticBody3D", true, false).size() == 4, "Each tower has exactly one foundation collider")
	var body_scene = load("res://scenes/blocs/Bloc.tscn")
	var body = body_scene.instantiate()
	body.linear_damp = 0.6
	body.get_node("ValueLabel").font_size = 52
	var info = {"id": 999, "value": 1, "cells": [Vector3i.ZERO, Vector3i(1, 0, 0)], "card": 0}
	body.build(info, Color.RED)
	check(is_equal_approx(body.linear_damp, 0.6) and body.get_node("ValueLabel").font_size == 52, "Building a piece preserves saved physics and label settings")
	check(body.collision_nodes.size() == 2 and body.get_node_or_null("SampleCell") == null, "Building a shape replaces the editor sample without duplicate collision geometry")
	var second = body_scene.instantiate()
	second.build(info, Color.BLUE)
	check(body.material != second.material and body.material.albedo_color == Color.RED, "Player tint does not leak between bloc material instances")
	body.free()
	second.free()
	scene.queue_free()
	await process_frame
	print("%s editor scenes: saved nodes and Inspector changes survive startup" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

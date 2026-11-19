extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_checks")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run_checks() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	for path in ["HUD/Root/ActionPrompt", "HUD/Root/Results", "HUD/Root/DiscardDialog"]:
		check(scene.has_node(path), "Presentation must be saved and editable: " + path)
	for value in range(1, 6):
		for variant in ["A", "B"]:
			check(ResourceLoader.exists("res://scenes/blocs/shapes/Bloc%d%s.tscn" % [value, variant]), "Every bloc shape needs an editable scene")
	if failures > 0:
		scene.free()
		quit(1)
		return
	root.add_child(scene)
	await process_frame
	var edited = load("res://scenes/blocs/shapes/Bloc1A.tscn").instantiate()
	edited.get_node("SampleCell").position = Vector3(0, 0, 1)
	var custom_material := StandardMaterial3D.new()
	custom_material.roughness = 0.19
	edited.get_node("SampleCell/Mesh").material_override = custom_material
	edited.build({"id": 999, "value": 1, "cells": [Vector3i.ZERO, Vector3i(1, 0, 0)], "card": 0}, Color.RED)
	check(edited.center == Vector3(0.5, 0, 0.5), "Authored cell positions drive runtime geometry")
	check(is_equal_approx(edited.material.roughness, 0.19), "Authored cell materials survive initialization")
	edited.set_tint(Color.BLUE)
	check(edited.collision_nodes.all(func(cell): return cell.get_node("Mesh").material_override.albedo_color == Color.BLUE), "Validity and owner tint reaches every cell")
	edited.free()
	scene.hud.choose(2)
	await process_frame
	var catalog = load("res://scripts/catalog.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pool: Array = catalog.build_pool(rng)
	for info in pool:
		check(info.has("scene_path"), "Supply points to the actual saved shape scene")
		var body = scene.board.create_bloc(info)
		check(body.scene_file_path == info.get("scene_path", ""), "Gameplay instances the saved shape")
		check(body.collision_nodes.size() == info.cells.size(), "Saved geometry and catalog cells agree")
		check(body.mass == float(info.cells.size()), "Shape mass remains unchanged")
		body.queue_free()
	scene.board.blocs.clear()
	await process_frame
	var hands = scene.hud.hands.get_children()
	check(hands.size() == 2 and hands[0].scene_file_path.ends_with("PlayerHand.tscn"), "Player hands use the saved row template")
	var discard = scene.hud.get_node("Root/DiscardDialog")
	scene.hud._show_discard()
	check(discard.visible and discard.get_node("%EmptyMessage").visible, "Saved discard dialog opens with empty state")
	discard.confirmed.emit()
	check(not discard.visible, "Discard dialog closes without being destroyed")
	scene.game.discard = [8]
	scene.hud._show_discard()
	check(discard.get_node("%Entries").get_child_count() == 1, "Discard rows are populated from saved templates")
	discard.confirmed.emit()
	scene.game._defeated(1)
	var results = scene.hud.get_node("Root/Results")
	check(results.visible and results.get_node("%ResultText").text.contains("Winner: P1"), "Defeat displays the winner in the saved result scene")
	check(not scene.hud.pending and not scene.hud.modal.visible, "Results cancel pending choices")
	scene.queue_free()
	await process_frame
	print("%s presentation: shape scenes, hand rows, discard and results" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

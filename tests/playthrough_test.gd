extends SceneTree
var scene
var steps := 0
var placements := 0
var seen_cards := {}
func _initialize() -> void: call_deferred("play")
func play() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	scene = current_scene
	scene.hud.choose(3)
	await process_frame
	# Deterministic decks and supply; leave the real turn engine and physics running.
	scene.game.active = 0
	scene.game.rng.seed = 752
	scene.game.pool = scene.game.Catalog.build_pool(scene.game.rng)
	scene.game.deck = [15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5]
	while not scene.game.over and steps < 30000:
		steps += 1
		if scene.hud.pending:
			var question: String = scene.hud.prompt_label.text
			var buttons: Array = scene.hud.options.get_children()
			if buttons.is_empty():
				push_error("Prompt has no options")
				quit(1)
				return
			# Exercise legislation whenever legal; finish restructuring after one selection.
			var index := 0
			if question.contains("ONE on-turn") and buttons.size() > 1:
				index = 1
			elif question.contains("reaction /") or question.contains("AFTER BLOCK DRAW") or question.contains("END OF TURN"):
				index = buttons.size() - 1
			buttons[index].pressed.emit()
		elif scene.board.preview != null and not scene.board.settling:
			var board = scene.board
			# Place raw shape cell zero above the tower, keeping its footprint valid.
			board.rotation_basis = Basis.IDENTITY
			board.grid = Vector3i(0, ceili(board.height(board.preview_owner)) + 1, 0)
			if board.preview.data.card != 0:
				board.grid.x = 1
				board.grid.z = 1
			board._update_preview()
			if board.valid_preview:
				placements += 1
				board.confirm_placement()
			else:
				push_error("Autoplay has no valid placement: " + board.preview_reason)
				quit(1)
				return
		await physics_frame
	if not scene.game.over:
		push_error("Autoplay did not finish before guard")
		quit(1)
		return
	if placements < 5 or scene.game.winner_ids.is_empty():
		push_error("Autoplay ended without sufficient gameplay or a winner")
		quit(1)
		return
	print("PASS real playthrough: %d placements, %d physics steps, phase %s, loser P%d, winners %s" % [placements, steps, scene.game.phase, scene.game.loser_id + 1, scene.game.winner_ids])
	quit()

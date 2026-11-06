extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func frames(count := 2) -> void:
	for _i in range(count): await process_frame
func run_tests() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	await frames()
	var scene = current_scene
	scene.hud.options.get_child(0).pressed.emit()
	await frames()
	check(scene.game.players.size() == 2 and scene.game.checkpoint, "Setup buttons create actual game")
	scene.game._request_debug("give", 15, (scene.game.active + 1) % 2, 3)
	await frames()
	check(scene.game.checkpoint and scene.game.players[(scene.game.active + 1) % 2].hand.has(15), "Debug mutation resumes checkpoint")
	scene.game._request_debug("force", 8, 0, 3)
	await frames()
	scene.hud.options.get_child(0).pressed.emit()
	await frames()
	check(scene.hud.prompt_label.text.contains("ONE on-turn"), "Normal turn draws forced card and prompts voluntary play")
	scene.hud.options.get_child(0).pressed.emit()
	await frames()
	check(scene.board.preview != null and not scene.hud.modal.visible, "Placement opens and prompt hides")
	scene.board.grid = Vector3i.ZERO
	scene.board._update_preview()
	if not scene.board.valid_preview:
		print("INVALID ", scene.board.preview_reason, " ", scene.board.preview.data, " grid ", scene.board.grid, " corners ", scene.board.preview.corners())
	check(scene.board.valid_preview, "Drawn piece has a valid foundation position")
	var discard_button = scene.hud.root.find_children("*", "Button", true, false).filter(func(button): return button.text == "Discard pile")[0]
	if discard_button.focus_mode != Control.FOCUS_NONE:
		discard_button.grab_focus()
	discard_button.pressed.emit()
	await frames()
	var dialog = scene.hud.root.get_children().filter(func(node): return node is AcceptDialog)[0]
	dialog.confirmed.emit()
	await frames()
	scene.hud.debug_panel.show()
	if scene.hud.pause_after.focus_mode != Control.FOCUS_NONE:
		scene.hud.pause_after.grab_focus()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	key.pressed = false
	Input.parse_input_event(key)
	var guard := 0
	while scene.board.settling and guard < 900:
		await physics_frame
		guard += 1
	await frames()
	check(scene.board.preview == null and scene.board.owned(scene.game.active).size() == 1, "Space releases real body and settlement completes")
	check(scene.hud.prompt_label.text.contains("END OF TURN"), "Actual UI opens extra-turn reaction")
	scene.hud.choose(15)
	await frames()
	scene.hud.choose(true)
	await frames()
	check(scene.game.checkpoint and scene.game.extra_turn, "Extra turn returns to checkpoint")
	scene.game.forced_card = 8
	scene.hud.choose("begin")
	await frames()
	scene.hud.choose(8)
	await frames()
	scene.hud.choose((scene.game.active + 1) % 2)
	await frames()
	check(scene.board.preview != null and scene.board.preview.data.value == -2, "Harmful physical card can be placed through real UI")
	var old_scene = weakref(scene)
	reload_current_scene()
	await frames(4)
	check(old_scene.get_ref() == null and current_scene.game == null and current_scene.hud.pending, "Restart during preview clears old game and returns to setup")
	current_scene.hud.choose(4)
	await frames()
	check(current_scene.game.players.size() == 4 and current_scene.board.origins.size() == 4, "Four-player setup works after restart")
	print("%s integration: setup, debug, UI prompts, Space input, settling, extra turn, card object, pending restart, four players" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

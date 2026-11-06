extends SceneTree
var scene
func _initialize() -> void: call_deferred("run_preview")
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(1280, 800)
	image.save_png(path)
func run_preview() -> void:
	scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await capture("/tmp/bloc_setup.png")
	scene.hud.choose(2)
	await process_frame
	scene.game.forced_card = 8
	await capture("/tmp/bloc_turn.png")
	scene.hud.choose("begin")
	await process_frame
	scene.hud.choose(0)
	await process_frame
	await capture("/tmp/bloc_placement.png")
	scene.hud.debug_panel.show()
	await capture("/tmp/bloc_debug.png")
	quit()

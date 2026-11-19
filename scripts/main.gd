extends Node3D
var board
var hud
var game

func _ready() -> void:
	Engine.time_scale = 1.0
	board = $Board
	hud = $HUD
	hud.get_node("%Sidebar").resized.connect(_sync_sidebar)
	_sync_sidebar()
	board.instruction.connect(func(text): hud.status.text = text)
	hud.start_requested.connect(_start)
	hud.setup_menu()

func _start(count: int) -> void:
	game = $GameManager
	game.configure(count, board, hud)
	game.run()

func _process(_delta: float) -> void:
	if board.preview != null:
		var lines: PackedStringArray = hud.status.text.split("\n")
		if lines.size() >= 2:
			hud.status.text = lines[0] + "\n" + lines[1] + "\n" + board.preview_reason

func _sync_sidebar() -> void:
	board.sidebar_width = hud.get_node("%Sidebar").size.x
	board._update_camera()

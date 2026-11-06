extends Node3D
const BoardScript = preload("res://scripts/board.gd")
const HUDScript = preload("res://scripts/hud.gd")
const GameScript = preload("res://scripts/game.gd")
var board
var hud
var game

func _ready() -> void:
	Engine.time_scale = 1.0
	board = $Board
	hud = HUDScript.new()
	add_child(hud)
	board.instruction.connect(func(text): hud.status.text = text)
	hud.start_requested.connect(_start)
	hud.setup_menu()

func _start(count: int) -> void:
	game = GameScript.new()
	add_child(game)
	game.configure(count, board, hud)
	game.run()

func _process(_delta: float) -> void:
	if board.preview != null:
		var lines: PackedStringArray = hud.status.text.split("\n")
		if lines.size() >= 2:
			hud.status.text = lines[0] + "\n" + lines[1] + "\n" + board.preview_reason

extends CanvasLayer

signal picked(value)
signal start_requested(count: int)
signal debug_requested(action: String, card: int, player: int, points: int)
var game
var root: Control
var status: Label
var scores: Label
var hands: VBoxContainer
var log_text: RichTextLabel
var modal: PanelContainer
var prompt_label: Label
var options: VBoxContainer
var pending := false
var debug_panel: VBoxContainer
var debug_buttons: Array[Button] = []
var card_picker: OptionButton
var player_picker: OptionButton
var points_picker: SpinBox
var pause_after: CheckButton
var logs: Array[String] = []

const ChoiceScene = preload("res://scenes/ui/ChoiceButton.tscn")
const HandScene = preload("res://scenes/ui/PlayerHand.tscn")
const DiscardEntryScene = preload("res://scenes/ui/DiscardEntry.tscn")
const CardScene = preload("res://scenes/ui/CardView.tscn")

func _ready() -> void:
	root = %Root
	status = %Status
	scores = %Scores
	hands = %Hands
	log_text = %EventLog
	modal = $Root/ActionPrompt
	prompt_label = modal.get_node("%PromptLabel")
	options = modal.get_node("%Options")
	debug_panel = %DebugPanel
	card_picker = %CardPicker
	player_picker = %PlayerPicker
	points_picker = %PointsPicker
	pause_after = %PauseAfter
	%Discard.pressed.connect(_show_discard)
	%Restart.pressed.connect(_restart)
	$Root/Results.get_node("%Restart").pressed.connect(_restart)
	$Root/DiscardDialog.confirmed.connect($Root/DiscardDialog.hide)
	$Root/DiscardDialog.canceled.connect($Root/DiscardDialog.hide)
	%DebugToggle.toggled.connect(func(value): debug_panel.visible = value)
	%SlowPhysics.toggled.connect(func(value): Engine.time_scale = 0.35 if value else 1.0)
	var catalog = preload("res://scripts/catalog.gd").cards()
	for id in catalog:
		card_picker.add_item("L%02d %s" % [id, catalog[id].name], id)
	for i in range(4):
		player_picker.add_item("P%d" % (i + 1), i)
	for child in debug_panel.get_children():
		if child is Button and child.has_meta("action"):
			var action: String = child.get_meta("action")
			child.pressed.connect(func(): debug_requested.emit(action, card_picker.get_selected_id(), player_picker.get_selected_id(), int(points_picker.value)))
			debug_buttons.append(child)
	log_text.text = ""
	scores.text = ""

func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = ChoiceScene.instantiate()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func ask(question: String, choices: Array):
	if game != null and game.over:
		return null
	pending = true
	prompt_label.text = question
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	for choice in choices:
		var value = choice.id
		var button := _button(options, choice.label, func(): choose(value))
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = choice.get("tooltip", choice.label)
	modal.show()
	if options.get_child_count() > 0:
		options.get_child(0).grab_focus()
	var answer = await picked
	return answer

func choose(value) -> void:
	if not pending:
		return
	pending = false
	modal.hide()
	var focused := root.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	picked.emit(value)

func setup_menu() -> void:
	# Use the saved menu buttons and text so editor changes survive startup.
	var action_modal = modal
	var action_label = prompt_label
	var action_options = options
	modal = $Root/MainMenu
	prompt_label = modal.get_node("%PromptLabel")
	options = modal.get_node("%Options")
	pending = true
	modal.show()
	for button in options.get_children():
		var count: int = button.get_meta("player_count")
		button.pressed.connect(func(): choose(count))
	options.get_child(0).grab_focus()
	var count = await picked
	modal = action_modal
	prompt_label = action_label
	options = action_options
	if count != null:
		start_requested.emit(int(count))

func log_event(text: String) -> void:
	logs.append(text)
	if logs.size() > 300:
		logs.pop_front()
	log_text.text = "\n".join(logs)

func refresh() -> void:
	if game == null:
		return
	var text := "%s / P%d\nSupply %d · Deck %d · Discard %d\n" % [game.phase, game.active + 1, game.pool.size(), game.deck.size(), game.discard.size()]
	for i in range(game.players.size()):
		text += "P%d   %d points   /   %d fallen\n" % [i + 1, game.board.score(i), game.board.fallen_counts[i]]
	scores.text = text
	for child in hands.get_children():
		hands.remove_child(child)
		child.queue_free()
	for i in range(game.players.size()):
		var hand = HandScene.instantiate()
		hands.add_child(hand)
		hand.get_node("%PlayerLabel").text = "P%d%s" % [i + 1, " / ACTIVE" if i == game.active else ""]
		hand.get_node("%EmptyMessage").visible = game.players[i].hand.is_empty()
		for id in game.players[i].hand:
			var card: Dictionary = game.cards[id]
			var button = CardScene.instantiate()
			button.text = "L%02d %s / %s" % [id, card.name, card.timing]
			button.tooltip_text = card.effect
			button.disabled = true
			hand.get_node("%Cards").add_child(button)
	for button in debug_buttons:
		button.disabled = not game.checkpoint or game.over

func _show_discard() -> void:
	if game == null:
		return
	var dialog: AcceptDialog = $Root/DiscardDialog
	var entries = dialog.get_node("%Entries")
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	dialog.get_node("%EmptyMessage").visible = game.discard.is_empty()
	for id in game.discard:
		var card: Dictionary = game.cards[id]
		var entry = DiscardEntryScene.instantiate()
		entry.text = "L%02d %s [%s]\n%s\n" % [id, card.name, card.timing, card.effect]
		entries.add_child(entry)
	dialog.popup_centered()

func show_result(text: String) -> void:
	choose(null)
	modal.hide()
	$Root/DiscardDialog.hide()
	var results = $Root/Results
	results.get_node("%ResultText").text = text
	results.show()
	results.get_node("%Restart").grab_focus()

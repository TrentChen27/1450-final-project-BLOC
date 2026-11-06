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

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	status = _label("", 20)
	status.position = Vector2(20, 18)
	status.size = Vector2(850, 90)
	root.add_child(status)
	var sidebar := PanelContainer.new()
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -370
	root.add_child(sidebar)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(sidebar_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	sidebar_scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_label("BLOC / RULES LAB", 24))
	scores = _label("", 17)
	column.add_child(scores)
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row, "Discard pile", _show_discard)
	_button(row, "Restart", func():
		Engine.time_scale = 1.0
		get_tree().reload_current_scene())
	column.add_child(_label("ALL HANDS / hover for full effects", 15))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 150
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	hands = VBoxContainer.new()
	hands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hands)
	var debug_toggle := CheckButton.new()
	debug_toggle.focus_mode = Control.FOCUS_NONE
	debug_toggle.text = "Playtest / debug controls"
	debug_toggle.toggled.connect(func(value): debug_panel.visible = value)
	column.add_child(debug_toggle)
	debug_panel = VBoxContainer.new()
	debug_panel.hide()
	column.add_child(debug_panel)
	card_picker = OptionButton.new()
	var catalog = preload("res://scripts/catalog.gd").cards()
	for id in catalog:
		card_picker.add_item("L%02d %s" % [id, catalog[id].name], id)
	debug_panel.add_child(card_picker)
	var settings := HBoxContainer.new()
	debug_panel.add_child(settings)
	player_picker = OptionButton.new()
	for i in range(4):
		player_picker.add_item("P%d" % (i + 1), i)
	settings.add_child(player_picker)
	points_picker = SpinBox.new()
	points_picker.min_value = 1
	points_picker.max_value = 5
	points_picker.value = 3
	settings.add_child(points_picker)
	for pair in [["Force next card", "force"], ["Give card to player", "give"], ["Place supply bloc", "spawn"], ["Add test bloc", "add"], ["Remove tower bloc", "remove"], ["Empty supply", "empty"], ["Next player", "next"]]:
		var action: String = pair[1]
		var button := _button(debug_panel, pair[0], func(): debug_requested.emit(action, card_picker.get_selected_id(), player_picker.get_selected_id(), int(points_picker.value)))
		debug_buttons.append(button)
	debug_panel.add_child(_label("Mutations available at turn checkpoints only.", 13))
	pause_after = CheckButton.new()
	pause_after.focus_mode = Control.FOCUS_NONE
	pause_after.text = "Pause after each physical action"
	debug_panel.add_child(pause_after)
	var slow := CheckButton.new()
	slow.focus_mode = Control.FOCUS_NONE
	slow.text = "Slow physics (0.35×)"
	slow.toggled.connect(func(value): Engine.time_scale = 0.35 if value else 1.0)
	debug_panel.add_child(slow)
	column.add_child(_label("EVENT LOG", 15))
	log_text = RichTextLabel.new()
	log_text.custom_minimum_size.y = 145
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(log_text)
	modal = PanelContainer.new()
	modal.position = Vector2(24, 140)
	modal.size = Vector2(800, 0)
	root.add_child(modal)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 18)
	modal.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)
	prompt_label = _label("", 20)
	content.add_child(prompt_label)
	var option_scroll := ScrollContainer.new()
	option_scroll.custom_minimum_size = Vector2(750, 290)
	content.add_child(option_scroll)
	options = VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.add_child(options)
	modal.hide()

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 34
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
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 42
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
	status.text = "BLOC\nA hot-seat tower-building rules prototype"
	var count = await ask("Choose players. All hands are visible for playtesting.\nBuild on your 4 × 4 mat; four fallen pieces in one action means defeat.", [{"id": 2, "label": "Start 2-player game"}, {"id": 3, "label": "Start 3-player game"}, {"id": 4, "label": "Start 4-player game"}])
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
		var label := _label("P%d%s" % [i + 1, " / ACTIVE" if i == game.active else ""], 16)
		hands.add_child(label)
		if game.players[i].hand.is_empty():
			hands.add_child(_label("No cards", 13))
		for id in game.players[i].hand:
			var card: Dictionary = game.cards[id]
			var button := Button.new()
			button.text = "L%02d %s / %s" % [id, card.name, card.timing]
			button.tooltip_text = card.effect
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.disabled = true
			hands.add_child(button)
	for button in debug_buttons:
		button.disabled = not game.checkpoint or game.over

func _show_discard() -> void:
	if game == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Legislation discard pile"
	dialog.min_size = Vector2i(680, 440)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650, 380)
	dialog.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	if game.discard.is_empty():
		content.add_child(_label("Discard pile is empty.", 18))
	for id in game.discard:
		var card: Dictionary = game.cards[id]
		content.add_child(_label("L%02d %s [%s]\n%s\n" % [id, card.name, card.timing, card.effect], 17))
	root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func show_result(text: String) -> void:
	choose(null)
	prompt_label.text = text
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	_button(options, "New game / player selection", func():
		Engine.time_scale = 1.0
		get_tree().reload_current_scene())
	modal.show()

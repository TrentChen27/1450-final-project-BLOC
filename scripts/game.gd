extends Node

const Catalog = preload("res://scripts/catalog.gd")
var board
var ui
var cards := Catalog.cards()
var rng := RandomNumberGenerator.new()
var players: Array = []
var pool: Array = []
var deck: Array = []
var discard: Array = []
var resolving: Array = []
var physical_cards: Array = []
var active := 0
var phase := "Production"
var over := false
var checkpoint := false
var extra_turn := false
var forced_card := 0
var debug_command: Dictionary = {}
var token_serial := 1000
var winner_ids: Array = []
var loser_id := -1

func configure(count: int, board_node, ui_node, seed_value := -1) -> void:
	board = board_node
	ui = ui_node
	ui.game = self
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for i in range(count):
		players.append({"hand": []})
	pool = Catalog.build_pool(rng)
	deck = cards.keys()
	_shuffle(deck)
	active = rng.randi_range(0, count - 1)
	board.setup(count)
	board.bloc_fell.connect(_on_fall)
	board.defeated.connect(_defeated)
	board.changed.connect(_refresh)
	ui.debug_requested.connect(_request_debug)
	log_event("New %d-player game. P%d starts. 30 blocs, %d unique legislation cards." % [count, active + 1, cards.size()])
	_refresh()

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = items[i]
		items[i] = items[j]
		items[j] = temp

func log_event(text: String) -> void:
	ui.log_event(text)

func _refresh() -> void:
	ui.refresh()

func run() -> void:
	while not over:
		board.focus_tower(active)
		checkpoint = true
		_refresh()
		var ready = await ui.ask("P%d / %s%s\nPass the controls to this player. Debug controls are available here." % [active + 1, phase, " / EXTRA TURN" if extra_turn else ""], [{"id": "begin", "label": "Begin turn"}])
		checkpoint = false
		_refresh()
		if over:
			return
		if ready == "debug":
			await _execute_debug()
			continue
		if pool.is_empty() and phase == "Production":
			phase = "Collapse"
			log_event("Supply exhausted: Collapse Phase. No more legislation.")
		if phase == "Collapse":
			await collapse_turn()
			if over:
				return
			await ui.ask("P%d relocation resolved." % (active + 1), [{"id": true, "label": "End turn"}])
			active = (active + 1) % players.size()
			extra_turn = false
			continue
		await production_turn()
		if over:
			return
		var extend := false
		# Exhaustion takes precedence over another normal (legislation) turn.
		if not pool.is_empty() and not extra_turn:
			extend = await end_reactions()
		if over:
			return
		await ui.ask("P%d turn complete. Scores updated." % (active + 1), [{"id": true, "label": "End turn"}])
		if over:
			return
		if pool.is_empty():
			phase = "Collapse"
			log_event("Supply exhausted: Collapse Phase. Legislation stops.")
			extend = false
		if extend:
			extra_turn = true
			log_event("P%d receives one extra normal turn." % (active + 1))
		else:
			extra_turn = false
			active = (active + 1) % players.size()

func production_turn() -> void:
	var card := draw_legislation()
	if card > 0:
		log_event("P%d draws L%02d — %s." % [active + 1, card, cards[card].name])
		if cards[card].timing == "IMMEDIATE":
			await play_card(card, active)
		else:
			players[active].hand.append(card)
			await enforce_hand(active)
	if over:
		return
	_refresh()
	var choices: Array = [{"id": 0, "label": "Skip voluntary legislation"}]
	for id in players[active].hand:
		if cards[id].timing == "ON_TURN" and can_play(id, active):
			choices.append(card_option(id))
	var chosen = await ui.ask("P%d may play ONE on-turn card." % (active + 1), choices)
	if over or chosen == null:
		return
	if chosen != 0:
		players[active].hand.erase(chosen)
		await play_card(chosen, active)
	if over:
		return
	var bloc := draw_bloc(0)
	if bloc.is_empty():
		return
	var context := {"bloc": bloc}
	await block_reactions(context)
	if over:
		return
	if not context.bloc.is_empty():
		await place(context.bloc, active, active)

func draw_legislation() -> int:
	if forced_card > 0:
		var chosen := forced_card
		forced_card = 0
		if _take_card(chosen):
			return chosen
	if deck.is_empty():
		for id in discard.duplicate():
			if not resolving.has(id):
				deck.append(id)
				discard.erase(id)
		_shuffle(deck)
		log_event("Reshuffled available discard cards into deck.")
	if deck.is_empty():
		log_event("No legislation available: all cards held or physical. Skip draw.")
		return 0
	return deck.pop_back()

func draw_bloc(points: int) -> Dictionary:
	var bloc := Catalog.draw(pool, points, rng)
	if bloc.is_empty():
		log_event("Supply empty: required placement skipped.")
	else:
		log_event("Supply draw: bloc #%d / %s / %d points%s." % [bloc.id, bloc.shape, bloc.value, " (fallback from %d)" % points if points > 0 and points != bloc.value else ""])
	_refresh()
	return bloc

func draw_and_place(points: int, owner: int) -> void:
	var bloc := draw_bloc(points)
	if not bloc.is_empty() and not over:
		await place(bloc, owner, owner)

func place(item, owner: int, controller: int, minimum := -INF) -> void:
	if over:
		return
	var data: Dictionary = item if item is Dictionary else item.data
	log_event("P%d placing %s (%+d) on P%d." % [controller + 1, data.shape, data.value, owner + 1])
	await board.place(item, owner, controller, minimum)
	log_scores()
	await _physical_checkpoint()

func remove(bloc) -> bool:
	if over or bloc.fallen or not bloc.placed:
		return false
	log_event("P%d removes bloc #%d. Removal is a separate action." % [bloc.owner_id + 1, bloc.data.id])
	var ok: bool = await board.remove_bloc(bloc)
	log_scores()
	await _physical_checkpoint()
	return ok and not over

func _physical_checkpoint() -> void:
	if not over and ui.pause_after.button_pressed:
		await ui.ask("Physical action settled. Review the towers and scores.", [{"id": true, "label": "Continue resolution"}])

func log_scores() -> void:
	var values: Array[String] = []
	for i in range(players.size()):
		values.append("P%d=%d" % [i + 1, board.score(i)])
	log_event("Scores: " + ", ".join(values))
	_refresh()

func card_option(id: int) -> Dictionary:
	return {"id": id, "label": "L%02d %s [%s]\n%s" % [id, cards[id].name, cards[id].timing, cards[id].effect]}

func enforce_hand(owner: int) -> void:
	_refresh()
	while players[owner].hand.size() > 3 and not over:
		var options: Array = []
		for id in players[owner].hand:
			options.append(card_option(id))
		var chosen = await ui.ask("P%d has more than three cards. Choose one to discard." % (owner + 1), options)
		if chosen == null:
			return
		players[owner].hand.erase(chosen)
		_discard(chosen)

func _discard(id: int) -> void:
	if not discard.has(id):
		discard.append(id)
	log_event("Discard L%02d — %s." % [id, cards[id].name])
	_refresh()

func legal_targets(id: int, actor: int) -> Array:
	if id == 10:
		return [actor]
	var legal: Array = []
	for i in range(players.size()):
		if i == actor:
			continue
		if id == 6 and board.owned(i).is_empty():
			continue
		if id == 14 and players[i].hand.is_empty():
			continue
		legal.append(i)
	return legal

func can_play(id: int, actor: int) -> bool:
	match id:
		5, 10: return not board.owned(actor).is_empty()
		6, 14: return not legal_targets(id, actor).is_empty()
		13: return not replay_options(actor).is_empty()
	return true

func replay_options(actor: int) -> Array:
	var options: Array = []
	for id in discard:
		if id != 13 and cards[id].timing != "REACTION" and can_play(id, actor):
			options.append(card_option(id))
	return options

func choose_target(id: int, actor: int) -> int:
	var choices: Array = []
	for target in legal_targets(id, actor):
		choices.append({"id": target, "label": "Target P%d" % (target + 1)})
	if choices.is_empty():
		log_event("No legal target for L%02d; effect skipped." % id)
		return -1
	var answer = await ui.ask("P%d: choose target for %s." % [actor + 1, cards[id].name], choices)
	return -1 if answer == null else int(answer)

func choose_bloc(owner: int, question: String):
	var choices: Array = []
	for bloc in board.owned(owner):
		choices.append({"id": bloc, "label": "Bloc #%d / %s / %+d points / top %.1f" % [bloc.data.id, bloc.data.shape, bloc.data.value, bloc.max_height()]})
	if choices.is_empty():
		log_event("P%d has no selectable bloc." % (owner + 1))
		return null
	board.focus_tower(owner)
	return await ui.ask(question, choices)

# Defense windows share a used-player set through redirection: no loops or double reactions.
func defenses(id: int, actor: int, target: int, global_effect := false) -> Dictionary:
	var context := {"target": target, "exempt": [], "cancelled": false}
	var used: Array = []
	var cursor := 1
	while cursor <= players.size() and not over:
		var reacting := (active + cursor) % players.size()
		cursor += 1
		if used.has(reacting):
			continue
		var choices: Array = [{"id": 0, "label": "Pass"}]
		if players[reacting].hand.has(12) and (global_effect or reacting == context.target):
			choices.append(card_option(12))
		var redirect_targets := legal_targets(id, actor).filter(func(p): return p != context.target)
		if not global_effect and players[reacting].hand.has(11) and not redirect_targets.is_empty():
			choices.append(card_option(11))
		if choices.size() == 1:
			continue
		var choice = await ui.ask("P%d reaction / %s\n%s" % [reacting + 1, "GLOBAL LEGISLATION" if global_effect else "P%d TARGETED" % (context.target + 1), cards[id].name], choices)
		if choice == null or over:
			return context
		log_event("P%d %s." % [reacting + 1, "passes" if choice == 0 else "reacts with L%02d" % choice])
		if choice == 0:
			continue
		used.append(reacting)
		players[reacting].hand.erase(choice)
		_discard(choice)
		if choice == 12:
			context.exempt.append(reacting)
			if not global_effect:
				context.cancelled = true
				break
		else:
			var target_options: Array = []
			for candidate in redirect_targets:
				target_options.append({"id": candidate, "label": "Redirect to P%d" % (candidate + 1)})
			var answer = await ui.ask("P%d: select a different legal target." % (reacting + 1), target_options)
			if answer == null:
				return context
			context.target = int(answer)
			log_event("L%02d redirected to P%d." % [id, context.target + 1])
			cursor = 1
	return context

func block_reactions(context: Dictionary) -> void:
	for offset in range(1, players.size()):
		if over or context.bloc.is_empty():
			return
		var reacting := (active + offset) % players.size()
		var choices: Array = [{"id": 0, "label": "Pass"}]
		for id in [9]:
			if players[reacting].hand.has(id):
				choices.append(card_option(id))
		if choices.size() == 1:
			continue
		var chosen = await ui.ask("P%d / AFTER BLOCK DRAW\nP%d revealed %s (%d points)." % [reacting + 1, active + 1, context.bloc.shape, context.bloc.value], choices)
		if chosen == null:
			return
		log_event("P%d %s after draw." % [reacting + 1, "passes" if chosen == 0 else "plays L%02d" % chosen])
		if chosen == 0:
			continue
		players[reacting].hand.erase(chosen)
		resolving.append(chosen)
		await place(context.bloc, reacting, reacting)
		if not over:
			context.bloc = draw_bloc(0)
		resolving.erase(chosen)
		_discard(chosen)

func end_reactions() -> bool:
	for offset in range(1, players.size()):
		var reacting := (active + offset) % players.size()
		if not players[reacting].hand.has(15):
			continue
		var chosen = await ui.ask("P%d / END OF TURN\nGive P%d one extra complete turn?" % [reacting + 1, active + 1], [{"id": 0, "label": "Pass"}, card_option(15)])
		if chosen == 15:
			players[reacting].hand.erase(15)
			_discard(15)
			return true
	return false

func play_card(id: int, actor: int, replay := false) -> void:
	if not cards.has(id):
		log_event("Unavailable legislation ID %d ignored." % id)
		return
	if over:
		return
	resolving.append(id)
	log_event("P%d %s L%02d — %s." % [actor + 1, "replays" if replay else "plays", id, cards[id].name])
	await resolve_effect(id, actor, replay)
	resolving.erase(id)
	if not replay and not physical_cards.has(id):
		_discard(id)
	_refresh()

func resolve_effect(id: int, actor: int, replay := false) -> void:
	if not cards.has(id):
		return
	match id:
		7:
			var response := await defenses(id, actor, -1, true)
			for offset in range(players.size()):
				var owner := (actor + offset) % players.size()
				if response.exempt.has(owner):
					log_event("P%d exempt from L%02d." % [owner + 1, id])
					continue
				for _n in range(2):
					if over:
						return
					await draw_and_place(1, owner)
		8:
			var target: int = await choose_target(id, actor)
			if target < 0:
				return
			var response := await defenses(id, actor, target)
			if response.cancelled or over:
				return
			# Self-only effects cannot be redirected; see legal_targets guard below.
			if not replay:
				physical_cards.append(id)
			token_serial += 1
			var token := {"id": token_serial, "value": -2, "cells": [Vector3i.ZERO], "shape": "L%02d physical card" % id, "card": id, "original_card": not replay}
			await place(token, response.target, actor)
		5, 6:
			var target := await choose_target(id, actor)
			if target < 0:
				return
			var response := await defenses(id, actor, target)
			if response.cancelled or over:
				return
			target = response.target
			var source := actor if id == 5 else target
			var destination := target if id == 5 else actor
			var bloc = await choose_bloc(source, "P%d chooses a bloc to transfer to P%d." % [source + 1, destination + 1])
			if bloc != null and await remove(bloc):
				await place(bloc, destination, destination)
		10:
			var response := await defenses(id, actor, actor)
			if response.cancelled or over:
				return
			var selected: Array = []
			while selected.size() < 4 and not over:
				var choices: Array = []
				if not selected.is_empty():
					choices.append({"id": "done", "label": "Done selecting / remove these %d blocs" % selected.size()})
				for bloc in board.owned(actor):
					if not selected.has(bloc):
						choices.append({"id": bloc, "label": "Select bloc #%d (%+d)" % [bloc.data.id, bloc.data.value]})
				if choices.is_empty():
					break
				var chosen = await ui.ask("P%d: select 1–4 blocs for restructuring." % (actor + 1), choices)
				if chosen == null:
					return
				if chosen is String:
					break
				selected.append(chosen)
			var held: Array = []
			for bloc in selected:
				if over:
					return
				if bloc.fallen:
					log_event("Selected bloc already fell; it cannot be recovered.")
				elif await remove(bloc):
					held.append(bloc)
			while not held.is_empty() and not over:
				var choices: Array = []
				for bloc in held:
					choices.append({"id": bloc, "label": "Replace bloc #%d (%+d)" % [bloc.data.id, bloc.data.value]})
				var chosen = await ui.ask("P%d: replace every removed bloc. Choose the next piece." % (actor + 1), choices)
				if chosen == null:
					return
				held.erase(chosen)
				await place(chosen, actor, actor)
		13:
			var choices := replay_options(actor)
			if choices.is_empty():
				log_event("No eligible discard to replay.")
				return
			var chosen = await ui.ask("Policy Reversal: select an eligible discard.", choices)
			if chosen != null:
				await play_card(chosen, actor, true)
		14:
			var target := await choose_target(id, actor)
			if target < 0:
				return
			var response := await defenses(id, actor, target)
			if response.cancelled or over:
				return
			target = response.target
			var choices: Array = []
			for held in players[target].hand:
				choices.append(card_option(held))
			if choices.is_empty():
				log_event("Target hand is empty after reactions; theft skipped.")
				return
			var chosen = await ui.ask("P%d: steal one card from P%d." % [actor + 1, target + 1], choices)
			if chosen != null:
				players[target].hand.erase(chosen)
				players[actor].hand.append(chosen)
				log_event("P%d stole L%02d from P%d." % [actor + 1, chosen, target + 1])
				await enforce_hand(actor)

func collapse_turn() -> void:
	if board.owned(active).is_empty():
		log_event("P%d cannot relocate: their tower is empty." % (active + 1))
		_defeated(active)
		return
	var bloc = await choose_bloc(active, "COLLAPSE / P%d\nSelect a bloc to remove and place higher." % (active + 1))
	if bloc == null:
		return
	var previous_top: float = bloc.max_height()
	if await remove(bloc):
		await place(bloc, active, active, previous_top)

func _on_fall(owner: int, data: Dictionary, action_id: int) -> void:
	log_event("FALL P%d: bloc #%d (%+d) / action %d / %d fallen in action." % [owner + 1, data.id, data.value, action_id, board.action_falls[owner]])
	if data.get("original_card", false):
		physical_cards.erase(data.card)
		_discard(data.card)
	_refresh()

func _defeated(owner: int) -> void:
	if over:
		return
	over = true
	checkpoint = false
	board.ended = true
	loser_id = owner
	var survivors: Array = []
	for i in range(players.size()):
		if i != owner:
			survivors.append(i)
	survivors.sort_custom(func(a, b):
		if board.score(a) != board.score(b):
			return board.score(a) > board.score(b)
		if board.fallen_counts[a] != board.fallen_counts[b]:
			return board.fallen_counts[a] < board.fallen_counts[b]
		return board.height(a) > board.height(b))
	var best: int = survivors[0]
	for i in survivors:
		if board.score(i) == board.score(best) and board.fallen_counts[i] == board.fallen_counts[best] and is_equal_approx(board.height(i), board.height(best)):
			winner_ids.append(i)
	var names: Array[String] = []
	for winner in winner_ids:
		names.append("P%d" % (winner + 1))
	var text := "GAME OVER / P%d defeated\n%s: %s\n\n" % [owner + 1, "Shared victory" if winner_ids.size() > 1 else "Winner", ", ".join(names)]
	for i in range(players.size()):
		text += "P%d: %d points / %d fallen / height %.1f%s\n" % [i + 1, board.score(i), board.fallen_counts[i], board.height(i), " / DEFEATED" if i == owner else ""]
	log_event(text)
	_refresh()
	ui.show_result(text)

func _take_card(id: int) -> bool:
	if not cards.has(id):
		return false
	if physical_cards.has(id) or resolving.has(id):
		log_event("L%02d is physical or resolving; cannot duplicate it." % id)
		return false
	deck.erase(id)
	discard.erase(id)
	for player in players:
		player.hand.erase(id)
	return true

func _request_debug(action: String, card: int, player: int, points: int) -> void:
	if not checkpoint or over:
		return
	debug_command = {"action": action, "card": card, "player": mini(player, players.size() - 1), "points": points}
	ui.choose("debug")

func _execute_debug() -> void:
	var cmd := debug_command
	if cmd.action in ["force", "give"] and not cards.has(cmd.card):
		log_event("Unavailable legislation ID %d ignored." % cmd.card)
		return
	log_event("DEBUG: %s / P%d." % [cmd.action, cmd.player + 1])
	match cmd.action:
		"force":
			if physical_cards.has(cmd.card):
				log_event("Card is already a physical object. Remove it first or reset.")
			else:
				forced_card = cmd.card
				log_event("Next legislation draw forced to L%02d." % cmd.card)
		"give":
			if _take_card(cmd.card):
				if cards[cmd.card].timing == "IMMEDIATE":
					await play_card(cmd.card, cmd.player)
				else:
					players[cmd.player].hand.append(cmd.card)
					await enforce_hand(cmd.player)
		"spawn": await draw_and_place(cmd.points, cmd.player)
		"add":
			token_serial += 1
			await place({"id": token_serial, "value": cmd.points, "shape": "test bloc", "cells": Catalog.shapes()[cmd.points][0], "card": 0}, cmd.player, cmd.player)
		"remove":
			var bloc = await choose_bloc(cmd.player, "DEBUG: select a bloc to remove permanently.")
			if bloc != null:
				await remove(bloc)
				if bloc.data.get("original_card", false):
					physical_cards.erase(bloc.data.card)
					_discard(bloc.data.card)
		"empty": pool.clear()
		"next":
			active = (active + 1) % players.size()
			extra_turn = false
	_refresh()

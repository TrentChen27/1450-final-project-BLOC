extends SceneTree
const Game = preload("res://scripts/game.gd")
const Board = preload("res://tests/fake_board.gd")
const UI = preload("res://tests/fake_ui.gd")
var g
var b
var u
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run_tests")
func fixture(count := 3) -> void:
	if g != null: g.free()
	g = Game.new()
	b = Board.new()
	u = UI.new()
	g.configure(count, b, u, 123)
	g.active = 0
func give(owner: int, id: int) -> void:
	assert(g._take_card(id))
	g.players[owner].hand.append(id)
func seed_bloc(owner: int, value := 2):
	var item: Dictionary = g.Catalog.draw(g.pool, value, g.rng)
	b.place(item, owner, owner)
	return b.blocs.back()
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
	checks += 1
func play(id: int, actor := 0) -> void:
	g._take_card(id)
	await g.play_card(id, actor)
func run_tests() -> void:
	fixture()
	check(g.deck.size() == 11 and g.deck.all(func(id): return id >= 5), "Deck excludes all four retired cards")
	for removed in range(1, 5):
		check(not g._take_card(removed), "Removed card cannot be given or forced")
		await g.play_card(removed, 0)
	check(b.actions.is_empty() and g.pool.size() == 30 and g.discard.is_empty(), "Retired effects cannot execute or enter discard")
	fixture()
	var transferred = seed_bloc(0)
	u.answers = [1, transferred]
	await play(5)
	check(b.score(0) == 0 and b.score(1) == 2 and b.actions[-2].type == "remove", "L05 ownership and separate actions")
	fixture()
	var seized = seed_bloc(1, 3)
	u.answers = [1, seized]
	await play(6)
	check(b.score(0) == 3 and b.score(1) == 0, "L06 seizure")
	fixture()
	await play(7)
	check(b.actions.size() == 6 and b.score(2) == 2, "L07 two placements each")
	fixture()
	u.answers = [1]
	await play(8)
	check(b.score(1) == -2 and b.actions[0].controller == 0, "L08 attacker places negative object")
	g._on_fall(1, b.blocs[0].data, 1)
	check(g.discard.has(8) and not g.physical_cards.has(8), "Physical card returns to discard on fall")
	fixture()
	give(1, 9)
	var context := {"bloc": g.draw_bloc(0)}
	var original_id: int = context.bloc.id
	u.answers = [9]
	await g.block_reactions(context)
	check(b.owned(1).size() == 1 and context.bloc.id != original_id and g.pool.size() == 28, "L09 replacement and interception")
	fixture()
	var first = seed_bloc(0)
	var second = seed_bloc(0, 3)
	u.answers = [first, second, "done", second, first]
	await play(10)
	check(b.score(0) == 5 and b.actions.slice(2).map(func(a): return a.type) == ["remove", "remove", "place", "place"], "L10 removes all before reordered replacement")
	fixture()
	give(1, 11)
	u.answers = [1, 11, 2]
	await play(8)
	check(b.score(1) == 0 and b.score(2) == -2 and g.discard.has(11), "L11 redirects to legal target")
	fixture()
	give(1, 12)
	u.answers = [1, 12]
	await play(8)
	check(b.actions.is_empty() and not g.physical_cards.has(8), "L12 cancels harmful physical card before placement")
	fixture()
	give(1, 12)
	u.answers = [12]
	await play(7)
	check(b.owned(1).is_empty() and b.owned(0).size() == 2 and b.owned(2).size() == 2, "L12 exempts only holder from global effect")
	fixture()
	g._take_card(8)
	g.discard.append(8)
	g._take_card(9)
	g.discard.append(9)
	check(g.replay_options(0).map(func(c): return c.id) == [8], "L13 rejects reaction cards")
	u.answers = [8, 1]
	await play(13)
	check(g.discard.count(8) == 1 and g.discard.has(13) and b.score(1) == -2 and not g.physical_cards.has(8), "L13 physical token preserves original discard")
	check(g.replay_options(0).all(func(c): return c.id != 13), "L13 cannot recurse")
	fixture()
	give(1, 15)
	give(0, 5)
	give(0, 10)
	give(0, 9)
	u.answers = [1, 15, 5]
	await play(14)
	check(g.players[0].hand.size() == 3 and g.players[0].hand.has(15) and g.players[1].hand.is_empty() and g.discard.has(5), "L14 theft and immediate overflow")
	fixture()
	give(1, 15)
	u.answers = [15]
	check(await g.end_reactions(), "L15 grants extra turn")
	check(g.discard.has(15), "L15 discarded")
	fixture(2)
	give(1, 9)
	context = {"bloc": g.draw_bloc(0), "extra": []}
	g.pool.clear()
	u.answers = [9]
	await g.block_reactions(context)
	check(context.bloc.is_empty() and b.owned(1).size() == 1, "Last-bloc interception skips unavailable replacement")
	fixture()
	g.deck.clear()
	g.discard.clear()
	check(g.draw_legislation() == 0, "Empty deck and discard skip draw")
	g.discard = [5, 7]
	g.resolving = [7]
	check(g.draw_legislation() == 5 and g.discard == [7], "Shuffle excludes resolving card")
	fixture()
	g.phase = "Collapse"
	await g.collapse_turn()
	check(g.over and g.loser_id == 0 and g.winner_ids == [1, 2], "Empty Collapse tower loses with shared survivor victory")
	fixture()
	first = seed_bloc(0)
	var old_top: float = first.top
	await g.collapse_turn()
	check(first.top > old_top and b.actions[-2].type == "remove", "Collapse higher replacement")
	fixture()
	seed_bloc(0)
	b.defeat_on_remove = true
	await g.collapse_turn()
	check(g.over and b.actions.size() == 2, "Defeat during removal prevents replacement")
	fixture()
	seed_bloc(1, 4)
	seed_bloc(2, 3)
	g._defeated(0)
	check(g.winner_ids == [1], "Winner uses surviving score")
	fixture(2)
	g.pool = [g.pool[0]]
	g.forced_card = 8
	await g.run()
	check(g.over and g.phase == "Collapse" and g.loser_id == 1, "Full turn progresses from final supply draw to empty-tower Collapse defeat")
	fixture(2)
	give(1, 15)
	g.forced_card = 8
	var turns: Array = []
	u.handler = func(question, options):
		if question.contains("Pass the controls"):
			turns.append([g.active, g.extra_turn])
			if turns.size() == 3:
				g._defeated(1)
				return null
		if question.contains("END OF TURN"):
			return 15
		return options[0].id
	await g.run()
	check(turns == [[0, false], [0, true], [1, false]], "Extended turn returns to original successor and cannot extend itself")
	g.free()
	g = null
	print("%s rules: %d checks / all 11 current cards, supply exhaustion, hand overflow, physical cards, Collapse, victory" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

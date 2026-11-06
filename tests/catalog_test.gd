extends SceneTree
func _initialize() -> void:
	var script = load("res://scripts/catalog.gd")
	if script == null:
		push_error("Catalog is required")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pool: Array = script.build_pool(rng)
	assert(pool.size() == 30)
	for value in range(1, 6):
		assert(pool.filter(func(b): return b.value == value).size() == 9 - value)
		assert(script.shapes()[value].size() >= 2)
	var ids := {}
	while not pool.is_empty():
		var bloc: Dictionary = script.draw(pool, 0, rng)
		assert(not ids.has(bloc.id))
		ids[bloc.id] = true
	assert(script.draw(pool, 3, rng).is_empty())
	pool = [{"id": 1, "value": 2}, {"id": 2, "value": 5}]
	assert(script.draw(pool, 4, rng).value == 2)
	assert(script.draw(pool, 1, rng).value == 5)
	assert(script.cards().size() == 11)
	for removed in range(1, 5):
		assert(not script.cards().has(removed))
	print("PASS catalog: quantities, unique instances, shape choices, lower/higher fallback, empty supply, 11 current cards")
	quit()

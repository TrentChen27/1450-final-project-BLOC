extends RefCounted

static func cards() -> Dictionary:
	return {
		5: {"name": "Forced Transfer", "timing": "ON_TURN", "effect": "Remove one bloc from your tower. Choose an opponent who must place it. Settle removal and placement separately."},
		6: {"name": "Asset Seizure", "timing": "ON_TURN", "effect": "Choose an opponent. They select a bloc to remove from their tower; you place it in yours before your normal draw."},
		7: {"name": "Emergency Production Order", "timing": "IMMEDIATE", "effect": "Starting with you, every player draws and places two separate 1-point blocs. Settle each individually."},
		8: {"name": "Bureaucratic Burden", "timing": "ON_TURN", "effect": "Choose an opponent. You place a physical -2 card on their tower. It counts as one bloc if it falls."},
		9: {"name": "Supply Interception", "timing": "REACTION", "effect": "After another player's normal draw: take and place their revealed bloc. They draw a replacement from supply."},
		10: {"name": "Restructuring Authority", "timing": "ON_TURN", "effect": "Select 1–4 blocs from your tower. Remove each separately, then replace all in any order. Settle after each operation."},
		11: {"name": "Administrative Reassignment", "timing": "REACTION", "effect": "Before single-target legislation resolves, choose a different legal target. Global legislation cannot be redirected."},
		12: {"name": "Personal Exemption", "timing": "REACTION", "effect": "Before targeted or global legislation affects you, ignore its complete effect on you. Other targets remain affected. Cannot undo falls."},
		13: {"name": "Policy Reversal", "timing": "ON_TURN", "effect": "Replay one eligible ON_TURN or IMMEDIATE discard under your control. Its original stays in discard. No reactions or Policy Reversal."},
		14: {"name": "Political Espionage", "timing": "ON_TURN", "effect": "Choose an opponent and steal one card from their visible hand. Discard immediately if your hand exceeds three."},
		15: {"name": "Extended Session", "timing": "REACTION", "effect": "At another player's turn end, give that player one extra normal turn. Extra turns cannot be extended again."},
	}

static func shapes() -> Dictionary:
	return {
		1: [[Vector3i(0,0,0), Vector3i(1,0,0)], [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(0,0,1)]],
		2: [[Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(2,0,0)], [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(2,0,0), Vector3i(0,0,1)]],
		3: [[Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(2,0,0), Vector3i(1,0,1)], [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,1,0), Vector3i(2,1,0)]],
		4: [[Vector3i(0,0,0), Vector3i(0,1,0), Vector3i(1,1,0), Vector3i(2,1,0), Vector3i(2,1,1)], [Vector3i(0,0,0), Vector3i(1,0,0), Vector3i(1,1,0), Vector3i(1,1,1), Vector3i(2,1,1)]],
		5: [[Vector3i(0,0,0), Vector3i(0,1,0), Vector3i(0,2,0), Vector3i(1,2,0), Vector3i(2,2,0)], [Vector3i(0,0,0), Vector3i(0,1,0), Vector3i(0,2,0), Vector3i(1,2,0), Vector3i(1,2,1)]],
	}

static func build_pool(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var geometry := shapes()
	for value in range(1, 6):
		for i in range(9 - value):
			pool.append({"id": pool.size() + 1, "value": value, "cells": geometry[value][i % 2].duplicate(), "shape": "%d-%s" % [value, "A" if i % 2 == 0 else "B"], "card": 0})
	# Fisher–Yates with a dedicated generator for repeatable tests.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	return pool

static func draw(pool: Array, requested: int, rng: RandomNumberGenerator) -> Dictionary:
	if pool.is_empty():
		return {}
	var eligible: Array = []
	if requested == 0:
		eligible = pool.duplicate()
	else:
		eligible = pool.filter(func(b): return b.value == requested)
		if eligible.is_empty():
			for value in range(requested - 1, 0, -1):
				eligible = pool.filter(func(b): return b.value == value)
				if not eligible.is_empty():
					break
		if eligible.is_empty():
			for value in range(requested + 1, 6):
				eligible = pool.filter(func(b): return b.value == value)
				if not eligible.is_empty():
					break
	var chosen: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
	pool.erase(chosen)
	return chosen

extends RefCounted
signal bloc_fell(owner: int, data: Dictionary, action_id: int)
signal defeated(owner: int)
signal changed
class TestBloc extends RefCounted:
	var data: Dictionary
	var owner_id := 0
	var placed := true
	var fallen := false
	var top := 1.0
	func max_height() -> float: return top
var blocs: Array = []
var fallen_counts: Array = []
var action_falls: Array = []
var actions: Array = []
var ended := false
var defeat_on_remove := false
func setup(count: int) -> void:
	fallen_counts.resize(count)
	fallen_counts.fill(0)
	action_falls.resize(count)
	action_falls.fill(0)
func focus_tower(_owner: int) -> void: pass
func owned(owner: int) -> Array:
	return blocs.filter(func(b): return b.owner_id == owner and b.placed and not b.fallen)
func score(owner: int) -> int:
	var total := 0
	for b in owned(owner): total += b.data.value
	return total
func height(owner: int) -> float:
	var maximum := 0.0
	for b in owned(owner): maximum = maxf(maximum, b.top)
	return maximum
func place(item, owner: int, controller: int, minimum := -INF) -> bool:
	var b
	if item is Dictionary:
		b = TestBloc.new()
		b.data = item.duplicate(true)
		blocs.append(b)
	else:
		b = item
	b.owner_id = owner
	b.placed = true
	b.top = maxf(height(owner) + 1.0, minimum + 1.0)
	actions.append({"type": "place", "owner": owner, "controller": controller, "data": b.data})
	return not ended
func remove_bloc(b) -> bool:
	b.placed = false
	actions.append({"type": "remove", "owner": b.owner_id, "data": b.data})
	if defeat_on_remove:
		ended = true
		defeated.emit(b.owner_id)
	return not ended

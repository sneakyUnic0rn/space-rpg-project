class_name GridPathfinder
## Works out where a unit can move and the cheapest route there.
## Straight steps cost 1 tile, diagonal steps cost 1.5 (so diagonals
## aren't a free shortcut). You can't cut a diagonal past a blocked corner.

const STRAIGHT: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const STRAIGHT_COST := 1.0
const DIAGONAL_COST := 1.5


## Every cell reachable from `start` within `max_cost`.
## `walkable` is a function that takes a Vector2i and returns true if a unit may stand there.
## Returns {"costs": {cell: cost}, "parents": {cell: previous cell}}.
static func reachable(start: Vector2i, max_cost: float, walkable: Callable) -> Dictionary:
	var costs := {start: 0.0}
	var parents := {start: start}
	var open: Array[Vector2i] = [start]

	while not open.is_empty():
		# Take the cheapest open cell (simple Dijkstra; our maps are small).
		var best_i := 0
		for i in range(1, open.size()):
			if costs[open[i]] < costs[open[best_i]]:
				best_i = i
		var current: Vector2i = open[best_i]
		open.remove_at(best_i)

		for dir in STRAIGHT + DIAGONAL:
			var next: Vector2i = current + dir
			if not walkable.call(next):
				continue
			var is_diagonal := dir.x != 0 and dir.y != 0
			if is_diagonal and (not walkable.call(current + Vector2i(dir.x, 0))
					or not walkable.call(current + Vector2i(0, dir.y))):
				continue
			var new_cost: float = costs[current] + (DIAGONAL_COST if is_diagonal else STRAIGHT_COST)
			if new_cost > max_cost + 0.001:
				continue
			if costs.has(next) and costs[next] <= new_cost:
				continue
			costs[next] = new_cost
			parents[next] = current
			open.append(next)

	return {"costs": costs, "parents": parents}


## The route from the start to `target`, not including the start cell.
## Empty if the target isn't reachable.
static func path_to(reach: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not reach["costs"].has(target):
		return path
	var cell := target
	while reach["parents"][cell] != cell:
		path.append(cell)
		cell = reach["parents"][cell]
	path.reverse()
	return path

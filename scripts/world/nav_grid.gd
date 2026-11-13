class_name NavGrid
extends Node3D
## Click-to-move pathfinding (RuneScape style) on a coarse walkability grid.
## Built once after the world exists: a cell is blocked when a static collider (house, fence,
## rock, tree) stands there at body height, when it is water without a pier, or when it is too steep.

const CELL: float = 1.25
const HALF_EXTENT: float = 105.0

var arena: TestArena
var ready_built: bool = false
var _astar := AStarGrid2D.new()
var _n: int = 0
## Walkable surface height per cell (terrain, or a walkway above it).
var surface := PackedFloat32Array()


func build(p_arena: TestArena) -> void:
	arena = p_arena
	_n = int(HALF_EXTENT * 2.0 / CELL)
	_astar.region = Rect2i(0, 0, _n, _n)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var space := get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 1.0
	probe.shape = shape
	probe.collision_mask = 1
	var excl: Array[RID] = []
	for nm: String in ["Terrain", "Crag", "SpirePath/StairDeck"]:
		var co: CollisionObject3D = arena.get_node_or_null(nm) as CollisionObject3D
		if co:
			excl.append(co.get_rid())
	probe.exclude = excl
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	var walk_ray := PhysicsRayQueryParameters3D.new()
	walk_ray.collision_mask = SpirePath.WALKWAY_LAYER
	# Pass 1: surface height per cell. Walkways (the stair, the crag top) lift a cell above the terrain.
	surface.resize(_n * _n)
	var on_walkway := PackedByteArray()
	on_walkway.resize(_n * _n)
	for j: int in _n:
		for i: int in _n:
			var p: Vector3 = cell_to_world(Vector2i(i, j))
			var gy: float = arena.height_at(p.x, p.z)
			var idx: int = j * _n + i
			surface[idx] = gy
			if Vector2(p.x, p.z).distance_to(TestArena.CLIFF_CENTER) < 32.0:
				walk_ray.from = Vector3(p.x, TestArena.CRAG_TOP + 12.0, p.z)
				walk_ray.to = Vector3(p.x, gy - 0.5, p.z)
				var wh: Dictionary = space.intersect_ray(walk_ray)
				if not wh.is_empty() and (wh["position"] as Vector3).y > gy + 0.05:
					surface[idx] = (wh["position"] as Vector3).y
					on_walkway[idx] = 1
	# Pass 2: blocked cells.
	for j: int in _n:
		for i: int in _n:
			var p: Vector3 = cell_to_world(Vector2i(i, j))
			var idx: int = j * _n + i
			var gy: float = surface[idx]
			var solid: bool = false
			if on_walkway[idx] == 1 or _near_walkway(on_walkway, i, j):
				# Walkways: a cell is blocked when it drops steeply to a neighbour (deck edge, top of a rock face).
				# The cell below such a drop stays open; the edge cell itself keeps the two apart.
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := Vector2i(i, j) + d
					if q.x >= 0 and q.y >= 0 and q.x < _n and q.y < _n and gy - surface[q.y * _n + q.x] > 0.85:
						solid = true
						break
				if not solid:
					probe.transform = Transform3D(Basis(), Vector3(p.x, gy + 1.0, p.z))
					solid = not space.intersect_shape(probe, 1).is_empty()
			elif gy < TestArena.WATER_LEVEL + 0.35:
				# Water: walkable only on a structure such as a pier.
				ray.from = Vector3(p.x, 3.0, p.z)
				ray.to = Vector3(p.x, TestArena.WATER_LEVEL, p.z)
				var hit: Dictionary = space.intersect_ray(ray)
				solid = hit.is_empty() or (hit["position"] as Vector3).y < TestArena.WATER_LEVEL + 0.4
			else:
				var slope: float = absf(arena.height_at(p.x + 1.0, p.z) - gy) + absf(arena.height_at(p.x, p.z + 1.0) - gy)
				if slope > 1.6:
					solid = true
				else:
					probe.transform = Transform3D(Basis(), Vector3(p.x, gy + 1.0, p.z))
					solid = not space.intersect_shape(probe, 1).is_empty()
			if solid:
				_astar.set_point_solid(Vector2i(i, j), true)
	ready_built = true


func _near_walkway(w: PackedByteArray, i: int, j: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := Vector2i(i, j) + d
		if q.x >= 0 and q.y >= 0 and q.x < _n and q.y < _n and w[q.y * _n + q.x] == 1:
			return true
	return false


## Surface height at a world position (walkway or terrain).
func surface_at(p: Vector3) -> float:
	if surface.is_empty():
		return arena.height_at(p.x, p.z)
	var c: Vector2i = world_to_cell(p)
	return surface[c.y * _n + c.x]


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + HALF_EXTENT) / CELL), 0, _n - 1), clampi(int((p.z + HALF_EXTENT) / CELL), 0, _n - 1))


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(-HALF_EXTENT + (c.x + 0.5) * CELL, 0.0, -HALF_EXTENT + (c.y + 0.5) * CELL)


func _nearest_open(c: Vector2i) -> Vector2i:
	if not _astar.is_point_solid(c):
		return c
	for r: int in range(1, 6):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var q := Vector2i(c.x + dx, c.y + dy)
				if _astar.is_in_boundsv(q) and not _astar.is_point_solid(q):
					return q
	return c


## World-space waypoints from `from` to `to` (excluding the start). Empty if no path.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not ready_built:
		out.append(to)
		return out
	var a: Vector2i = _nearest_open(world_to_cell(from))
	var b: Vector2i = _nearest_open(world_to_cell(to))
	var ids: Array[Vector2i] = _astar.get_id_path(a, b, true)
	# Keep every few cells plus turns: the controller steers smoothly between them.
	for k: int in range(1, ids.size()):
		out.append(cell_to_world(ids[k]))
	if not out.is_empty():
		out[out.size() - 1] = Vector3(to.x, 0.0, to.z) if not _astar.is_point_solid(world_to_cell(to)) else out[out.size() - 1]
	return out


func is_blocked(p: Vector3) -> bool:
	return ready_built and _astar.is_point_solid(world_to_cell(p))

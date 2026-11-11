class_name DefenseGridNav
extends RefCounted

## DefenseGridNav: Verwaltet das diskrete 2D-Raster und die A*-Wegfindung
## Kernkonzept: Mazing-Invariante (Anti-Jailing-Schutz) & dynamisches Re-Pathing.

signal path_updated()

var grid_width: int = 24
var grid_height: int = 16
var cell_size: float = 40.0

var start_cell: Vector2i = Vector2i(0, 8)
var goal_cell: Vector2i = Vector2i(23, 8)

var astar: AStarGrid2D = null
var tower_grid: Dictionary = {} # Vector2i -> Node (Tower)

func _init(w: int = 24, h: int = 16, c_size: float = 40.0) -> void:
	grid_width = w
	grid_height = h
	cell_size = c_size
	start_cell = Vector2i(0, h / 2)
	goal_cell = Vector2i(w - 1, h / 2)
	_setup_astar()

func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid_width, grid_height)
	astar.cell_size = Vector2(cell_size, cell_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # Reines 4-Wege-Mazing (Manhattan)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / cell_size)), int(floor(world_pos.y / cell_size)))

func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func is_cell_solid(cell: Vector2i) -> bool:
	if not is_valid_cell(cell):
		return true
	return astar.is_point_solid(cell)

func has_tower(cell: Vector2i) -> bool:
	return tower_grid.has(cell)

## Mazing-Invariante: Prüft, ob ein Turmbau die Route vom Start zum Ziel
## oder von bestehenden Creeps zum Ziel vollständig abschnüren würde (Anti-Jailing).
func can_build_tower(cell: Vector2i, active_creeps: Array = []) -> bool:
	# 1. Raster-Grenzen prüfen
	if not is_valid_cell(cell):
		return false

	# 2. Start- und Zielzelle dürfen niemals bebaut werden
	if cell == start_cell or cell == goal_cell:
		return false

	# 3. Zelle bereits besetzt?
	if is_cell_solid(cell) or has_tower(cell):
		return false

	# 4. Spekulative Simulation: Setze Zelle temporär auf Solid
	astar.set_point_solid(cell, true)

	# A: Gibt es weiterhin einen Weg vom Spawn-Portal zum Ziel?
	var main_path = astar.get_id_path(start_cell, goal_cell)
	var path_exists = not main_path.is_empty()

	# B: Werden bereits herumlaufende Creeps eingesperrt (Jailing)?
	if path_exists and not active_creeps.is_empty():
		for creep in active_creeps:
			if creep != null and is_instance_valid(creep) and creep.is_active:
				var c_cell = world_to_cell(creep.position)
				if is_valid_cell(c_cell):
					var creep_path = astar.get_id_path(c_cell, goal_cell)
					if creep_path.is_empty():
						path_exists = false
						break

	# 5. Spekulatives Solid zurücknehmen
	astar.set_point_solid(cell, false)

	return path_exists

func place_tower(cell: Vector2i, tower_instance: Node = null) -> bool:
	if not is_valid_cell(cell) or is_cell_solid(cell):
		return false

	astar.set_point_solid(cell, true)
	if tower_instance:
		tower_grid[cell] = tower_instance
	path_updated.emit()
	return true

func remove_tower(cell: Vector2i) -> Node:
	if not is_valid_cell(cell) or not is_cell_solid(cell):
		return null

	astar.set_point_solid(cell, false)
	var tower = tower_grid.get(cell, null)
	tower_grid.erase(cell)
	path_updated.emit()
	return tower

## Berechnet den schnellsten Welt-Koordinaten-Pfad für einen Creep
func get_world_path(from_world: Vector2, to_world: Vector2 = Vector2.INF) -> PackedVector2Array:
	var from_cell = world_to_cell(from_world)
	var to_cell = goal_cell if to_world == Vector2.INF else world_to_cell(to_world)

	if not is_valid_cell(from_cell):
		from_cell.x = clampi(from_cell.x, 0, grid_width - 1)
		from_cell.y = clampi(from_cell.y, 0, grid_height - 1)

	var cell_path = astar.get_id_path(from_cell, to_cell)
	var world_path = PackedVector2Array()

	for c in cell_path:
		world_path.append(cell_to_world(c))

	return world_path

## Berechnet den globalen Hauptpfad von Start nach Ziel
func get_main_path() -> PackedVector2Array:
	return get_world_path(cell_to_world(start_cell), cell_to_world(goal_cell))

extends SceneTree

## Headless Testsuite für Cyber Tower Defense
## Überprüft A* Grid-Wegfindung, Mazing-Invariante (Anti-Jailing), dynamisches Re-Pathing,
## Zero-Allocation Object Pooling und Turm-Sensorik.

const DefenseGridNav = preload("res://core/defense_grid_nav.gd")
const ObjectPool = preload("res://core/object_pool.gd")
const Creep = preload("res://scripts/creep.gd")
const DefenseTower = preload("res://scripts/tower.gd")
const DefenseProjectile = preload("res://scripts/projectile.gd")
const WaveManager = preload("res://scripts/wave_manager.gd")
const MainDefense = preload("res://scenes/main.gd")

func _init() -> void:
	print("==================================================")
	print("🧪 STARTE TESTS: Cyber Tower Defense (A* Mazing TD)")
	print("==================================================")

	var failed = false

	if not test_astar_grid_pathfinding():
		print("❌ TEST 1 FEHLGESCHLAGEN: A* Grid-Wegfindung & Heuristik")
		failed = true
	else:
		print("✅ TEST 1 BESTANDEN: A* Grid-Wegfindung & Heuristik")

	if not test_mazing_invariant_and_jailing():
		print("❌ TEST 2 FEHLGESCHLAGEN: Mazing-Invariante (Anti-Jailing-Schutz)")
		failed = true
	else:
		print("✅ TEST 2 BESTANDEN: Mazing-Invariante (Anti-Jailing-Schutz)")

	if not test_creep_dynamic_repathing():
		print("❌ TEST 3 FEHLGESCHLAGEN: Creep Dynamisches Re-Pathing")
		failed = true
	else:
		print("✅ TEST 3 BESTANDEN: Creep Dynamisches Re-Pathing")

	if not test_object_pool_zero_allocation():
		print("❌ TEST 4 FEHLGESCHLAGEN: Zero-Allocation Object Pool Invariante")
		failed = true
	else:
		print("✅ TEST 4 BESTANDEN: Zero-Allocation Object Pool Invariante")

	if not test_tower_sensor_and_priority():
		print("❌ TEST 5 FEHLGESCHLAGEN: Turm-Sensorik & Zielpriorisierung")
		failed = true
	else:
		print("✅ TEST 5 BESTANDEN: Turm-Sensorik & Zielpriorisierung")

	if not test_main_scene_game_loop():
		print("❌ TEST 6 FEHLGESCHLAGEN: Main-Szene & Game Loop")
		failed = true
	else:
		print("✅ TEST 6 BESTANDEN: Main-Szene & Game Loop")

	print("==================================================")
	if failed:
		print("❌ EINIGE TESTS SIND FEHLGESCHLAGEN!")
		quit(1)
	else:
		print("🎉 ALLE TESTS ERFOLGREICH ABGESCHLOSSEN!")
		quit(0)

func test_astar_grid_pathfinding() -> bool:
	var nav = DefenseGridNav.new(10, 10, 40.0)
	nav.start_cell = Vector2i(0, 0)
	nav.goal_cell = Vector2i(9, 9)
	nav._setup_astar()

	# 1. Freies Raster: Diagonale Distanz via Manhattan = 9 + 9 = 18 Schritte (19 Punkte)
	var path = nav.astar.get_id_path(Vector2i(0, 0), Vector2i(9, 9))
	if path.size() != 19:
		print("  -> Unerwartete Pfadlänge im freien Raster: ", path.size(), " (erwartet 19)")
		return false

	# 2. Hindernis bei (1, 0) setzen: Pfad muss ausweichen über (0, 1)
	nav.astar.set_point_solid(Vector2i(1, 0), true)
	var detour_path = nav.astar.get_id_path(Vector2i(0, 0), Vector2i(9, 9))
	if detour_path.size() != 19 or detour_path[1] != Vector2i(0, 1):
		print("  -> A* weicht dem Hindernis nicht korrekt aus: ", detour_path)
		return false

	return true

func test_mazing_invariant_and_jailing() -> bool:
	var nav = DefenseGridNav.new(6, 6, 40.0)
	nav.start_cell = Vector2i(0, 2)
	nav.goal_cell = Vector2i(5, 2)
	nav._setup_astar()

	# Baue eine vertikale Wand bei X = 3 von Y = 0 bis Y = 4 (lässt nur Y = 5 frei)
	for y in range(5):
		var ok = nav.can_build_tower(Vector2i(3, y))
		if not ok:
			print("  -> Baubares Wandsegment wurde fälschlicherweise blockiert bei (3, ", y, ")")
			return false
		nav.place_tower(Vector2i(3, y))

	# Der letzte freie Durchgang bei (3, 5): Wenn hier gebaut wird, ist der Weg versperrt!
	var can_block = nav.can_build_tower(Vector2i(3, 5))
	if can_block:
		print("  -> FEHLER: Mazing-Invariante verletzt! Vollständiges Blockieren wurde genehmigt!")
		return false

	# Start- und Zielzelle dürfen niemals bebaut werden
	if nav.can_build_tower(nav.start_cell) or nav.can_build_tower(nav.goal_cell):
		print("  -> FEHLER: Bau auf Start- oder Zielzelle wurde genehmigt!")
		return false

	return true

func test_creep_dynamic_repathing() -> bool:
	var nav = DefenseGridNav.new(8, 8, 40.0)
	nav.start_cell = Vector2i(0, 3)
	nav.goal_cell = Vector2i(7, 3)
	nav._setup_astar()

	var creep = Creep.new()
	var initial_path = nav.get_world_path(nav.cell_to_world(Vector2i(0, 3)))
	creep.setup(Creep.CreepType.SCOUT, 50.0, 100.0, 5, initial_path)

	# Simuliere Bewegung zu Wegpunkt 2
	creep.waypoint_index = 2
	var old_next_point = creep.path[creep.waypoint_index]

	# Baue nun einen Turm genau vor den Creep
	var block_cell = nav.world_to_cell(old_next_point)
	if nav.can_build_tower(block_cell, [creep]):
		nav.place_tower(block_cell)
		var new_path = nav.get_world_path(creep.position)
		creep.set_new_path(new_path)

		# Neuer Pfad darf die blockierte Zelle nicht mehr enthalten
		var new_cell_path = []
		for pt in creep.path:
			new_cell_path.append(nav.world_to_cell(pt))

		if new_cell_path.has(block_cell):
			print("  -> Dynamisches Re-Pathing enthält weiterhin die blockierte Zelle!")
			creep.free()
			return false

	creep.free()
	return true

func test_object_pool_zero_allocation() -> bool:
	var parent = Node.new()
	var pool = ObjectPool.new()
	pool.initialize(10, func(): return Creep.new(), parent)

	if pool.get_capacity() != 10 or pool.get_available_count() != 10 or pool.get_active_count() != 0:
		print("  -> Pool Initial-Zustand fehlerhaft!")
		parent.free()
		return false

	# 5 Items acquirieren
	var acquired = []
	for i in range(5):
		var item = pool.acquire()
		if item == null or not item.visible or item.process_mode != Node.PROCESS_MODE_INHERIT:
			print("  -> Pool Acquire fehlerhaft!")
			parent.free()
			return false
		acquired.append(item)

	if pool.get_active_count() != 5 or pool.get_available_count() != 5:
		print("  -> Pool Zähler-Invariante nach Acquire verletzt!")
		parent.free()
		return false

	# 2 Items releasen
	pool.release(acquired[0])
	pool.release(acquired[1])

	if pool.get_active_count() != 3 or pool.get_available_count() != 7:
		print("  -> Pool Zähler-Invariante nach Release verletzt!")
		parent.free()
		return false

	pool.reset_all()
	if pool.get_active_count() != 0 or pool.get_available_count() != 10:
		print("  -> Pool Reset All fehlerhaft!")
		parent.free()
		return false

	parent.free()
	return true

func test_tower_sensor_and_priority() -> bool:
	var tower = DefenseTower.new()
	tower.setup(DefenseTower.TowerType.GATLING, Vector2i(5, 5))
	tower.position = Vector2(200, 200)
	tower.range_radius = 100.0

	var creep_far = Creep.new()
	creep_far.position = Vector2(500, 500) # Außerhalb Reichweite
	creep_far.is_active = true

	var creep_near_1 = Creep.new()
	creep_near_1.position = Vector2(250, 200) # In Reichweite (Distanz 50)
	creep_near_1.waypoint_index = 2
	creep_near_1.is_active = true

	var creep_near_2 = Creep.new()
	creep_near_2.position = Vector2(220, 200) # In Reichweite (Distanz 20), aber weiter vorn im Weg
	creep_near_2.waypoint_index = 5
	creep_near_2.is_active = true

	var fired = [false]
	tower.fired_projectile.connect(func(_from, target, _dmg, _spd, _splash, _slow_f, _slow_d):
		fired[0] = true
		if target != creep_near_2:
			print("  -> Priorisierung fehlerhaft: Nicht der am weitesten fortgeschrittene Creep wurde anvisiert!")
	)

	# Update: Turm muss creep_near_2 wählen (Progress = 5 vs 2)
	tower.update_target_and_fire([creep_far, creep_near_1, creep_near_2], 0.3)

	if not fired[0]:
		print("  -> Turm hat Ziel in Reichweite nicht beschossen!")
		tower.free()
		creep_far.free()
		creep_near_1.free()
		creep_near_2.free()
		return false

	tower.free()
	creep_far.free()
	creep_near_1.free()
	creep_near_2.free()
	return true

func test_main_scene_game_loop() -> bool:
	var scene_res = load("res://scenes/main.tscn")
	if scene_res == null:
		print("  -> main.tscn konnte nicht geladen werden!")
		return false

	var scene: MainDefense = scene_res.instantiate() as MainDefense
	if scene == null:
		print("  -> main.tscn Instanziierung fehlgeschlagen!")
		return false

	root.add_child(scene)
	if not scene.is_node_ready():
		scene._ready()

	# Überprüfe Initial-Credits und Pools
	if scene.credits != 100 or scene.lives != 20:
		print("  -> Startwerte fehlerhaft: Credits=", scene.credits, " Leben=", scene.lives)
		scene.free()
		return false

	# Teste Turmbau
	var build_ok = scene._attempt_build_tower(Vector2i(5, 5))
	if not build_ok:
		print("  -> Validierter Turmbau in Main-Szene fehlgeschlagen!")
		scene.free()
		return false

	if scene.credits != 85: # 100 - 15 = 85
		print("  -> Credits nach Turmbau nicht korrekt abgezogen: ", scene.credits)
		scene.free()
		return false

	scene.free()
	return true

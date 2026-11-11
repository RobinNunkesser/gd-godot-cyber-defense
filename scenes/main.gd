class_name MainDefense
extends Node2D

## MainDefense: Hauptszene für Cyber Tower Defense
## Demonstriert A*-Mazing-Validierung, dynamisches Re-Pathing und Turm-Sensorik.

const DefenseGridNav = preload("res://core/defense_grid_nav.gd")
const ObjectPool = preload("res://core/object_pool.gd")
const Creep = preload("res://scripts/creep.gd")
const DefenseTower = preload("res://scripts/tower.gd")
const DefenseProjectile = preload("res://scripts/projectile.gd")
const WaveManager = preload("res://scripts/wave_manager.gd")

# Komponenten
var grid_nav: DefenseGridNav = null
var creep_pool: ObjectPool = null
var projectile_pool: ObjectPool = null
var wave_manager: WaveManager = null

# Container
var grid_visual: Node2D = null
var towers_container: Node2D = null
var creeps_container: Node2D = null
var projectiles_container: Node2D = null
var ui_layer: CanvasLayer = null

# Spielzustand
var credits: int = 100
var lives: int = 20
var score: int = 0
var game_over: bool = false
var game_speed: float = 1.0

# Turm-Platzierung
var selected_build_type: DefenseTower.TowerType = DefenseTower.TowerType.GATLING
var is_build_mode: bool = true
var hovered_cell: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var selected_tower: DefenseTower = null

# Statistik für Didaktik
var astar_paths_computed: int = 0

# UI-Elemente
var stats_label: Label = null
var tower_info_panel: PanelContainer = null
var tower_info_label: Label = null
var upgrade_btn: Button = null
var sell_btn: Button = null
var next_wave_btn: Button = null

class GridVisualizer extends Node2D:
	var main: MainDefense = null

	func _init(p_main: MainDefense) -> void:
		main = p_main

	func _draw() -> void:
		if main == null or main.grid_nav == null:
			return

		var w = main.grid_nav.grid_width
		var h = main.grid_nav.grid_height
		var cs = main.grid_nav.cell_size

		# 1. Raster-Hintergrund
		draw_rect(Rect2(0, 0, w * cs, h * cs), Color(0.04, 0.06, 0.09))

		# 2. Gitter-Linien (dezent)
		for x in range(w + 1):
			var col = Color(0.12, 0.16, 0.24, 0.5)
			draw_line(Vector2(x * cs, 0), Vector2(x * cs, h * cs), col, 1.0)
		for y in range(h + 1):
			var col = Color(0.12, 0.16, 0.24, 0.5)
			draw_line(Vector2(0, y * cs), Vector2(w * cs, y * cs), col, 1.0)

		# 3. Start- und Zielportal hervorheben
		var start_p = main.grid_nav.cell_to_world(main.grid_nav.start_cell)
		var goal_p = main.grid_nav.cell_to_world(main.grid_nav.goal_cell)

		draw_circle(start_p, cs * 0.45, Color(0.1, 0.9, 0.4, 0.3))
		draw_arc(start_p, cs * 0.45, 0, TAU, 16, Color(0.1, 0.9, 0.4), 2.0)

		draw_circle(goal_p, cs * 0.45, Color(0.95, 0.2, 0.3, 0.3))
		draw_arc(goal_p, cs * 0.45, 0, TAU, 16, Color(0.95, 0.2, 0.3), 2.0)

		# 4. Aktueller A*-Hauptpfad als Cyber-Leuchtlinie visualisieren
		var main_path = main.grid_nav.get_main_path()
		if main_path.size() > 1:
			draw_polyline(main_path, Color(0.0, 0.9, 1.0, 0.25), 4.0)
			for pt in main_path:
				draw_circle(pt, 2.5, Color(0.0, 0.9, 1.0, 0.4))

		# 5. Bau-Vorschau (Hover-Cursor)
		if main.is_build_mode and main.grid_nav.is_valid_cell(main.hovered_cell):
			var r = Rect2(main.hovered_cell.x * cs + 2, main.hovered_cell.y * cs + 2, cs - 4, cs - 4)
			var hover_col = Color(0.2, 1.0, 0.4, 0.35) if main.is_hover_valid else Color(1.0, 0.2, 0.2, 0.35)
			var border_col = Color(0.2, 1.0, 0.4, 0.9) if main.is_hover_valid else Color(1.0, 0.2, 0.2, 0.9)
			draw_rect(r, hover_col)
			draw_rect(r, border_col, false, 2.0)

			# Reichweitenkreis des zu bauenden Turms
			var center = main.grid_nav.cell_to_world(main.hovered_cell)
			var range_r = 115.0
			if main.selected_build_type == DefenseTower.TowerType.CANNON:
				range_r = 150.0
			elif main.selected_build_type == DefenseTower.TowerType.EMP:
				range_r = 95.0
			draw_arc(center, range_r, 0, TAU, 32, Color(border_col.r, border_col.g, border_col.b, 0.3), 1.5)

func _ready() -> void:
	_setup_grid_and_pools()
	_setup_containers()
	_setup_wave_manager()
	_setup_ui()
	_update_hover_status()

func _setup_grid_and_pools() -> void:
	grid_nav = DefenseGridNav.new(24, 16, 40.0)

	creep_pool = ObjectPool.new()
	creep_pool.initialize(60, func():
		var c = Creep.new()
		c.reached_goal.connect(_on_creep_reached_goal)
		c.killed.connect(_on_creep_killed)
		return c
	)

	projectile_pool = ObjectPool.new()
	projectile_pool.initialize(100, func():
		var p = DefenseProjectile.new()
		p.expired.connect(func(proj): projectile_pool.release(proj))
		return p
	)

func _setup_containers() -> void:
	grid_visual = GridVisualizer.new(self)
	grid_visual.name = "GridVisual"
	add_child(grid_visual)

	towers_container = Node2D.new()
	towers_container.name = "TowersContainer"
	add_child(towers_container)

	creeps_container = Node2D.new()
	creeps_container.name = "CreepsContainer"
	add_child(creeps_container)

	# Creeps und Projektile im Pool den Containern zuweisen
	for c in creep_pool.get_active_items() + creep_pool._available:
		if c.get_parent() == null:
			creeps_container.add_child(c)

	projectiles_container = Node2D.new()
	projectiles_container.name = "ProjectilesContainer"
	add_child(projectiles_container)

	for p in projectile_pool.get_active_items() + projectile_pool._available:
		if p.get_parent() == null:
			projectiles_container.add_child(p)

func _setup_wave_manager() -> void:
	wave_manager = WaveManager.new()
	wave_manager.creep_spawn_requested.connect(_on_spawn_creep_requested)
	wave_manager.wave_started.connect(func(w): _update_ui())
	wave_manager.wave_completed.connect(func(w):
		credits += 25 + w * 5 # Wellen-Bonus
		_update_ui()
	)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# Rechte Sidebar für Controls & Didaktik-Monitoring (Position ab X=980)
	var sidebar = PanelContainer.new()
	sidebar.position = Vector2(980, 10)
	sidebar.custom_minimum_size = Vector2(285, 700)
	ui_layer.add_child(sidebar)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	sidebar.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "🛡️ CYBER DEFENSE (A* TD)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_lbl)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stats_label)

	var hsep1 = HSeparator.new()
	vbox.add_child(hsep1)

	var build_title = Label.new()
	build_title.text = "🏗️ TÜRME BAUEN (Click auf Grid):"
	build_title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(build_title)

	var btn_gatling = Button.new()
	btn_gatling.text = "Gatling [1] - 15 Cr (Schnell)"
	btn_gatling.pressed.connect(func(): _select_build_tower(DefenseTower.TowerType.GATLING))
	vbox.add_child(btn_gatling)

	var btn_cannon = Button.new()
	btn_cannon.text = "Kanone [2] - 25 Cr (Schwer)"
	btn_cannon.pressed.connect(func(): _select_build_tower(DefenseTower.TowerType.CANNON))
	vbox.add_child(btn_cannon)

	var btn_emp = Button.new()
	btn_emp.text = "EMP [3] - 30 Cr (Slow Aura)"
	btn_emp.pressed.connect(func(): _select_build_tower(DefenseTower.TowerType.EMP))
	vbox.add_child(btn_emp)

	var hsep2 = HSeparator.new()
	vbox.add_child(hsep2)

	# Turm-Detail-Inspektor
	tower_info_panel = PanelContainer.new()
	tower_info_panel.visible = false
	vbox.add_child(tower_info_panel)

	var t_vbox = VBoxContainer.new()
	tower_info_panel.add_child(t_vbox)

	tower_info_label = Label.new()
	tower_info_label.add_theme_font_size_override("font_size", 12)
	t_vbox.add_child(tower_info_label)

	upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade (Stufe +1)"
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	t_vbox.add_child(upgrade_btn)

	sell_btn = Button.new()
	sell_btn.text = "Verkaufen (70% Refund)"
	sell_btn.pressed.connect(_on_sell_pressed)
	t_vbox.add_child(sell_btn)

	# Wellen-Steuerung
	next_wave_btn = Button.new()
	next_wave_btn.text = "▶️ NÄCHSTE WELLE [Leertaste]"
	next_wave_btn.pressed.connect(func(): wave_manager.start_next_wave())
	vbox.add_child(next_wave_btn)

	var btn_speed = Button.new()
	btn_speed.text = "⏩ Tempo: 1x / 2x"
	btn_speed.pressed.connect(_toggle_game_speed)
	vbox.add_child(btn_speed)

	_update_ui()

func _select_build_tower(type: DefenseTower.TowerType) -> void:
	selected_build_type = type
	is_build_mode = true
	_deselect_tower()
	_update_hover_status()

func _toggle_game_speed() -> void:
	game_speed = 2.0 if is_equal_approx(game_speed, 1.0) else 1.0
	Engine.time_scale = game_speed
	_update_ui()

func _physics_process(delta: float) -> void:
	if game_over:
		return

	# 1. Wellen-Logik aktualisieren
	wave_manager.update(delta, creep_pool.get_active_count())

	# 2. Türme aktualisieren & feuern
	var active_creeps = creep_pool.get_active_items()
	for child in towers_container.get_children():
		if child is DefenseTower:
			child.update_target_and_fire(active_creeps, delta)

	# 3. UI-Status aktualisieren
	_update_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_cell = grid_nav.world_to_cell(event.position)
		if new_cell != hovered_cell:
			hovered_cell = new_cell
			_update_hover_status()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_grid_click(event.position)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_select_build_tower(DefenseTower.TowerType.GATLING)
		elif event.keycode == KEY_2:
			_select_build_tower(DefenseTower.TowerType.CANNON)
		elif event.keycode == KEY_3:
			_select_build_tower(DefenseTower.TowerType.EMP)
		elif event.keycode == KEY_SPACE:
			wave_manager.start_next_wave()
		elif event.keycode == KEY_R:
			_restart_game()

func _handle_grid_click(click_pos: Vector2) -> void:
	var cell = grid_nav.world_to_cell(click_pos)
	if not grid_nav.is_valid_cell(cell):
		return

	# Klick auf existierenden Turm?
	if grid_nav.has_tower(cell):
		_select_tower(grid_nav.tower_grid[cell])
		return

	# Turmbau ausführen
	if is_build_mode:
		_attempt_build_tower(cell)

func _attempt_build_tower(cell: Vector2i) -> bool:
	var cost = 15
	if selected_build_type == DefenseTower.TowerType.CANNON:
		cost = 25
	elif selected_build_type == DefenseTower.TowerType.EMP:
		cost = 30

	if credits < cost:
		return false

	var active_creeps = creep_pool.get_active_items()
	astar_paths_computed += 1

	# Mazing-Invariante prüfen (Anti-Jailing)
	if not grid_nav.can_build_tower(cell, active_creeps):
		return false

	credits -= cost
	var tower = DefenseTower.new()
	towers_container.add_child(tower)
	tower.position = grid_nav.cell_to_world(cell)
	tower.setup(selected_build_type, cell)
	tower.fired_projectile.connect(_on_tower_fired)

	grid_nav.place_tower(cell, tower)

	# Dynamisches Re-Pathing für alle herumlaufenden Creeps
	_repath_all_creeps()

	_update_hover_status()
	_update_ui()
	grid_visual.queue_redraw()
	return true

func _repath_all_creeps() -> void:
	for c in creep_pool.get_active_items():
		if c != null and is_instance_valid(c) and c.is_active:
			astar_paths_computed += 1
			var new_p = grid_nav.get_world_path(c.position)
			c.set_new_path(new_p)

func _update_hover_status() -> void:
	if grid_nav == null:
		return
	if is_build_mode and grid_nav.is_valid_cell(hovered_cell):
		is_hover_valid = grid_nav.can_build_tower(hovered_cell, creep_pool.get_active_items())
	else:
		is_hover_valid = false
	if grid_visual:
		grid_visual.queue_redraw()

func _select_tower(t: DefenseTower) -> void:
	_deselect_tower()
	selected_tower = t
	selected_tower.set_selected(true)
	tower_info_panel.visible = true
	_update_tower_inspector()

func _deselect_tower() -> void:
	if selected_tower != null:
		selected_tower.set_selected(false)
		selected_tower = null
	if tower_info_panel:
		tower_info_panel.visible = false

func _update_tower_inspector() -> void:
	if selected_tower == null:
		return
	var type_name = "Gatling" if selected_tower.tower_type == DefenseTower.TowerType.GATLING else ("Kanone" if selected_tower.tower_type == DefenseTower.TowerType.CANNON else "EMP")
	tower_info_label.text = "Turm: %s (Stufe %d)\nDPS: %.1f | Reichweite: %.0f px\nInvestiert: %d Cr" % [
		type_name, selected_tower.level, (selected_tower.damage / selected_tower.fire_rate),
		selected_tower.range_radius, selected_tower.total_invested
	]
	var up_cost = selected_tower.get_upgrade_cost()
	upgrade_btn.text = "Upgrade (%d Cr)" % up_cost if up_cost > 0 else "Max Stufe"
	upgrade_btn.disabled = (up_cost == 0 or credits < up_cost)
	sell_btn.text = "Verkaufen (+%d Cr)" % selected_tower.get_sell_value()

func _on_upgrade_pressed() -> void:
	if selected_tower == null:
		return
	var cost = selected_tower.get_upgrade_cost()
	if cost > 0 and credits >= cost:
		credits -= cost
		selected_tower.upgrade()
		_update_tower_inspector()
		_update_ui()
		grid_visual.queue_redraw()

func _on_sell_pressed() -> void:
	if selected_tower == null:
		return
	var refund = selected_tower.get_sell_value()
	credits += refund
	var cell = selected_tower.grid_cell
	grid_nav.remove_tower(cell)
	selected_tower.queue_free()
	_deselect_tower()
	_repath_all_creeps()
	_update_ui()
	grid_visual.queue_redraw()

func _on_spawn_creep_requested(type: int, hp: float, spd: float, bounty: int) -> void:
	var creep: Creep = creep_pool.acquire() as Creep
	if creep:
		var start_p = grid_nav.cell_to_world(grid_nav.start_cell)
		var p = grid_nav.get_world_path(start_p)
		astar_paths_computed += 1
		creep.setup(type as Creep.CreepType, hp, spd, bounty, p)

func _on_tower_fired(from: Vector2, target: Creep, dmg: float, spd: float, splash: float, slow_f: float, slow_d: float) -> void:
	var proj: DefenseProjectile = projectile_pool.acquire() as DefenseProjectile
	if proj:
		proj.fire(from, target, dmg, spd, splash, slow_f, slow_d)

func _on_creep_reached_goal(c: Creep) -> void:
	lives = maxi(0, lives - 1)
	creep_pool.release(c)
	if lives <= 0:
		game_over = true
	_update_ui()

func _on_creep_killed(c: Creep) -> void:
	credits += c.bounty
	score += c.bounty * 10
	creep_pool.release(c)
	_update_ui()

func _update_ui() -> void:
	if stats_label == null:
		return
	var w_status = "Aktiv (%d Creeps)" % creep_pool.get_active_count() if wave_manager.is_wave_active else "Bereit in %.1fs" % wave_manager.time_until_next_wave
	stats_label.text = """❤️ Leben: %d
💰 Credits: %d
🏆 Score: %d
🌊 Welle: %d (%s)
🔍 A*-Pfade: %d
⚡ Tempo: %.1fx""" % [lives, credits, score, wave_manager.current_wave, w_status, astar_paths_computed, game_speed]

	if game_over:
		stats_label.text += "\n\n💥 GAME OVER!\nDrücke [R] für Neustart"

func _restart_game() -> void:
	credits = 100
	lives = 20
	score = 0
	game_over = false
	astar_paths_computed = 0
	creep_pool.reset_all()
	projectile_pool.reset_all()
	wave_manager.reset()
	for child in towers_container.get_children():
		child.queue_free()
	grid_nav = DefenseGridNav.new(24, 16, 40.0)
	_deselect_tower()
	_update_ui()
	grid_visual.queue_redraw()


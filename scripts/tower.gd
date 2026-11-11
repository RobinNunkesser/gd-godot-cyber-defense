class_name DefenseTower
extends Node2D

const Creep = preload("res://scripts/creep.gd")

## DefenseTower: Verteidigungsturm mit weicher Zielerfassung und Priorisierung.
## Implementiert Sensorik, Zielauswahl (First in Range) und Drehung.

signal fired_projectile(from: Vector2, target: Creep, dmg: float, spd: float, splash: float, slow_f: float, slow_d: float)

enum TowerType { GATLING, CANNON, EMP }

@export var tower_type: TowerType = TowerType.GATLING
@export var level: int = 1
@export var base_cost: int = 15
@export var range_radius: float = 120.0
@export var fire_rate: float = 0.25
@export var damage: float = 12.0
@export var projectile_speed: float = 480.0
@export var splash_radius: float = 0.0
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0

var grid_cell: Vector2i = Vector2i.ZERO
var current_target: Creep = null
var turret_angle: float = 0.0
var fire_timer: float = 0.0
var is_selected: bool = false
var total_invested: int = 15

func _ready() -> void:
	z_index = 4

func setup(p_type: TowerType, p_cell: Vector2i) -> void:
	tower_type = p_type
	grid_cell = p_cell
	level = 1

	match tower_type:
		TowerType.GATLING:
			base_cost = 15
			damage = 12.0
			range_radius = 115.0
			fire_rate = 0.22 # Schnellfeuer
			projectile_speed = 520.0
			splash_radius = 0.0
			slow_factor = 1.0
			slow_duration = 0.0
		TowerType.CANNON:
			base_cost = 25
			damage = 45.0
			range_radius = 150.0
			fire_rate = 0.85 # Schwere Artillerie
			projectile_speed = 400.0
			splash_radius = 35.0
			slow_factor = 1.0
			slow_duration = 0.0
		TowerType.EMP:
			base_cost = 30
			damage = 15.0
			range_radius = 95.0
			fire_rate = 1.1 # Verlangsamung
			projectile_speed = 360.0
			splash_radius = 45.0
			slow_factor = 0.45
			slow_duration = 2.2

	total_invested = base_cost
	queue_redraw()

func upgrade() -> bool:
	if level >= 3:
		return false
	level += 1
	var upgrade_cost = int(base_cost * 0.8 * level)
	total_invested += upgrade_cost
	damage *= 1.45
	range_radius *= 1.15
	fire_rate *= 0.85
	queue_redraw()
	return true

func get_upgrade_cost() -> int:
	if level >= 3:
		return 0
	return int(base_cost * 0.8 * (level + 1))

func get_sell_value() -> int:
	return int(total_invested * 0.7)

func update_target_and_fire(active_creeps: Array, delta: float) -> void:
	fire_timer -= delta

	# 1. Ziel validieren oder neues suchen (Priorität: Creep am weitesten auf dem Pfad)
	if not _is_target_valid(current_target):
		current_target = _find_best_target(active_creeps)

	# 2. Turm-Drehung weich interpolieren
	if current_target != null:
		var target_vec = current_target.position - position
		var desired_angle = target_vec.angle()
		turret_angle = lerp_angle(turret_angle, desired_angle, 14.0 * delta)

		# 3. Schießen, wenn bereit
		if fire_timer <= 0.0:
			fire_timer = fire_rate
			var muzzle_offset = Vector2.from_angle(turret_angle) * 14.0
			fired_projectile.emit(
				position + muzzle_offset,
				current_target,
				damage,
				projectile_speed,
				splash_radius,
				slow_factor,
				slow_duration
			)
	queue_redraw()

func _is_target_valid(c: Creep) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_active:
		return false
	return position.distance_squared_to(c.position) <= range_radius * range_radius

func _find_best_target(active_creeps: Array) -> Creep:
	var best_creep: Creep = null
	var highest_progress: int = -1
	var closest_dist_sq: float = INF
	var range_sq = range_radius * range_radius

	for c in active_creeps:
		if c != null and is_instance_valid(c) and c.is_active:
			var d_sq = position.distance_squared_to(c.position)
			if d_sq <= range_sq:
				# Priorisiere Creeps, die am weitesten fortgeschritten sind (höchster Wegpunkt-Index)
				if c.waypoint_index > highest_progress:
					highest_progress = c.waypoint_index
					best_creep = c
					closest_dist_sq = d_sq
				elif c.waypoint_index == highest_progress and d_sq < closest_dist_sq:
					best_creep = c
					closest_dist_sq = d_sq

	return best_creep

func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()

func _draw() -> void:
	# 1. Sockel / Basis (32x32 px)
	var base_rect = Rect2(Vector2(-16, -16), Vector2(32, 32))
	var base_color = Color(0.12, 0.16, 0.24)
	draw_rect(base_rect, base_color)
	draw_rect(base_rect, Color(0.2, 0.35, 0.5), false, 1.5)

	# 2. Turm-Kopf & Rohr (drehbar)
	var barrel_col: Color
	match tower_type:
		TowerType.GATLING:
			barrel_col = Color(0.1, 0.8, 1.0)
		TowerType.CANNON:
			barrel_col = Color(1.0, 0.45, 0.1)
		TowerType.EMP:
			barrel_col = Color(0.2, 1.0, 0.5)

	# Lauf
	var barrel_len = 16.0
	var barrel_end = Vector2.from_angle(turret_angle) * barrel_len
	draw_line(Vector2.ZERO, barrel_end, barrel_col, 4.0)

	# Zentrale Kuppel
	draw_circle(Vector2.ZERO, 9.0, base_color)
	draw_circle(Vector2.ZERO, 6.0, barrel_col)
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(1, 1, 1, 0.7), 1.5)

	# 3. Level-Indikator (kleine Punkte)
	for i in range(level):
		var p_x = -6.0 + i * 6.0
		draw_circle(Vector2(p_x, 12.0), 2.0, Color.YELLOW)

	# 4. Reichweitenkreis (wenn selektiert)
	if is_selected:
		draw_arc(Vector2.ZERO, range_radius, 0, TAU, 48, Color(0.2, 0.9, 1.0, 0.4), 1.5)
		draw_circle(Vector2.ZERO, range_radius, Color(0.2, 0.9, 1.0, 0.05))

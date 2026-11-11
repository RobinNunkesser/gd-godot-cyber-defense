class_name Creep
extends Node2D

## Creep: Gegnereinheit im Tower-Defense-Netzwerk
## Folgt Wegpunkten aus AStarGrid2D und unterstützt dynamisches Re-Pathing.

signal reached_goal(creep: Creep)
signal killed(creep: Creep)

enum CreepType { SCOUT, TANK, BOSS }

@export var speed: float = 80.0
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var bounty: int = 5
@export var collision_radius: float = 14.0

var creep_type: CreepType = CreepType.SCOUT
var is_active: bool = false

var path: PackedVector2Array = PackedVector2Array()
var waypoint_index: int = 0

var slow_timer: float = 0.0
var slow_factor: float = 1.0

func _ready() -> void:
	z_index = 5

func on_pool_acquire() -> void:
	is_active = true
	slow_timer = 0.0
	slow_factor = 1.0
	waypoint_index = 0

func on_pool_release() -> void:
	is_active = false
	path.clear()
	waypoint_index = 0
	slow_timer = 0.0
	slow_factor = 1.0

func setup(p_type: CreepType, p_hp: float, p_speed: float, p_bounty: int, p_path: PackedVector2Array) -> void:
	creep_type = p_type
	max_health = p_hp
	current_health = p_hp
	speed = p_speed
	bounty = p_bounty
	path = p_path
	waypoint_index = 0
	if not path.is_empty():
		position = path[0]
	queue_redraw()

func set_new_path(new_path: PackedVector2Array) -> void:
	if new_path.is_empty():
		return
	path = new_path
	# Nächsten Wegpunkt finden, der vor uns liegt
	waypoint_index = 0
	if path.size() > 1 and position.distance_squared_to(path[0]) < 16.0:
		waypoint_index = 1

func take_damage(amount: float) -> void:
	if not is_active:
		return
	current_health -= amount
	queue_redraw()
	if current_health <= 0:
		is_active = false
		killed.emit(self)

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = maxf(slow_timer, duration)

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Slow-Debuff verwalten
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0

	# Bewegung entlang des Pfades
	if waypoint_index >= path.size():
		is_active = false
		reached_goal.emit(self)
		return

	var target_pos = path[waypoint_index]
	var effective_speed = speed * slow_factor
	var step = effective_speed * delta
	var dist = position.distance_to(target_pos)

	if dist <= step:
		position = target_pos
		waypoint_index += 1
		if waypoint_index >= path.size():
			is_active = false
			reached_goal.emit(self)
	else:
		position += (target_pos - position).normalized() * step

func _draw() -> void:
	# 1. Creep-Körper basierend auf Typ
	match creep_type:
		CreepType.SCOUT:
			# Schneller Neon-Scout (Diamant / Rhombus)
			var col = Color(0.1, 0.9, 1.0, 0.9)
			var pts = PackedVector2Array([
				Vector2(0, -12), Vector2(10, 0),
				Vector2(0, 12), Vector2(-10, 0)
			])
			draw_colored_polygon(pts, col)
			draw_polyline(pts, Color(1, 1, 1), 1.5)
		CreepType.TANK:
			# Schwerer Panzer (Massives Hexagon)
			var col = Color(1.0, 0.45, 0.1, 0.95)
			draw_circle(Vector2.ZERO, 14.0, col)
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 16, Color(1, 1, 1), 2.0)
		CreepType.BOSS:
			# Kybernetischer Boss (Doppelring)
			var col = Color(0.9, 0.15, 0.35, 1.0)
			draw_circle(Vector2.ZERO, 18.0, col)
			draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1.0, 0.8, 0.2), 3.0)

	# 2. Lebensbalken (Health Bar)
	var bar_w = 24.0
	var bar_h = 3.5
	var bar_pos = Vector2(-bar_w * 0.5, -20.0)
	var hp_ratio = clampf(current_health / max_health, 0.0, 1.0)

	# Hintergrund
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.1, 0.1, 0.1, 0.8))
	# Füllung (Grün -> Gelb -> Rot)
	var fill_col = Color.GREEN.lerp(Color.RED, 1.0 - hp_ratio)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_ratio, bar_h)), fill_col)


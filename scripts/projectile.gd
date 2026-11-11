class_name DefenseProjectile
extends Node2D

const Creep = preload("res://scripts/creep.gd")

## DefenseProjectile: Allokationsfreies Plasma-Geschoss
## Steuert das Ziel direkt an oder detoniert bei Erreichen.

signal expired(proj: DefenseProjectile)

@export var speed: float = 450.0
@export var damage: float = 25.0
@export var splash_radius: float = 0.0
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0

var target: Creep = null
var last_target_pos: Vector2 = Vector2.ZERO
var is_active: bool = false
var lifetime: float = 0.0

func _ready() -> void:
	z_index = 8

func on_pool_acquire() -> void:
	is_active = true
	lifetime = 0.0
	target = null

func on_pool_release() -> void:
	is_active = false
	target = null
	lifetime = 0.0

func fire(from: Vector2, p_target: Creep, p_dmg: float, p_speed: float, p_splash: float = 0.0, p_slow_f: float = 1.0, p_slow_d: float = 0.0) -> void:
	position = from
	target = p_target
	damage = p_dmg
	speed = p_speed
	splash_radius = p_splash
	slow_factor = p_slow_f
	slow_duration = p_slow_d
	is_active = true
	lifetime = 0.0
	if is_instance_valid(target):
		last_target_pos = target.position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	lifetime += delta
	if lifetime >= 2.5: # Timeout
		_expire()
		return

	if is_instance_valid(target) and target.is_active:
		last_target_pos = target.position

	var to_target = last_target_pos - position
	var dist = to_target.length()
	var step = speed * delta

	if dist <= step:
		position = last_target_pos
		_impact()
	else:
		position += to_target.normalized() * step

func _impact() -> void:
	if is_instance_valid(target) and target.is_active:
		target.take_damage(damage)
		if slow_duration > 0.0:
			target.apply_slow(slow_factor, slow_duration)
	_expire()

func _expire() -> void:
	is_active = false
	expired.emit(self)

func _draw() -> void:
	# Strahlendes Plasma-Geschoss
	var col = Color(0.2, 1.0, 0.4) if slow_duration > 0 else (Color(1.0, 0.6, 0.1) if splash_radius > 0 else Color(0.1, 0.8, 1.0))
	draw_circle(Vector2.ZERO, 3.5, col)
	draw_arc(Vector2.ZERO, 5.0, 0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)

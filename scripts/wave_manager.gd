class_name WaveManager
extends RefCounted

const Creep = preload("res://scripts/creep.gd")

## WaveManager: Koordiniert den Wellen-Ablauf, Spawns und Creep-Zusammensetzungen.

signal wave_started(wave_num: int)
signal wave_completed(wave_num: int)
signal creep_spawn_requested(type: int, hp: float, speed: float, bounty: int)

var current_wave: int = 0
var creeps_to_spawn: Array[Dictionary] = []
var spawn_timer: float = 0.0
var spawn_interval: float = 0.85
var is_wave_active: bool = false

var time_until_next_wave: float = 6.0
var auto_start_next: bool = true

func start_next_wave() -> void:
	if is_wave_active:
		return

	current_wave += 1
	is_wave_active = true
	creeps_to_spawn = _generate_wave_data(current_wave)
	spawn_timer = 0.0
	wave_started.emit(current_wave)

func _generate_wave_data(w: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var count = 8 + w * 3
	var hp_mult = 1.0 + (w - 1) * 0.28
	var spd_mult = 1.0 + minf((w - 1) * 0.03, 0.4)

	# Jede 5. Welle ist eine Boss-Welle
	var is_boss_wave = (w % 5 == 0)

	for i in range(count):
		var c_type = Creep.CreepType.SCOUT
		var hp = 65.0 * hp_mult
		var spd = 85.0 * spd_mult
		var reward = 5

		if is_boss_wave and i == count - 1:
			c_type = Creep.CreepType.BOSS
			hp = 500.0 * hp_mult
			spd = 55.0
			reward = 50
		elif w >= 2 and i % 3 == 0:
			c_type = Creep.CreepType.TANK
			hp = 160.0 * hp_mult
			spd = 50.0 * spd_mult
			reward = 12

		list.append({
			"type": c_type,
			"hp": hp,
			"speed": spd,
			"bounty": reward
		})

	return list

func update(delta: float, active_creeps_count: int) -> void:
	if is_wave_active:
		if not creeps_to_spawn.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = spawn_interval
				var data = creeps_to_spawn.pop_front()
				creep_spawn_requested.emit(data.type, data.hp, data.speed, data.bounty)
		elif active_creeps_count == 0:
			# Welle komplett abgewehrt!
			is_wave_active = false
			time_until_next_wave = 6.0
			wave_completed.emit(current_wave)
	else:
		if auto_start_next:
			time_until_next_wave -= delta
			if time_until_next_wave <= 0.0:
				start_next_wave()

func reset() -> void:
	current_wave = 0
	creeps_to_spawn.clear()
	is_wave_active = false
	time_until_next_wave = 6.0

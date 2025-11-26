# wave_manager.gd
extends Node

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed

@export var enemy_scene: PackedScene
@export var spawn_points: Array[Marker3D] = []
@export var goal_marker: Marker3D

var current_wave: int = 0
var enemies_alive: int = 0

func start_wave():
	current_wave += 1
	wave_started.emit(current_wave)
	
	var enemy_count = 5 + (current_wave * 2)  # Scales with wave
	
	for i in enemy_count:
		spawn_enemy()
		await get_tree().create_timer(1.0).timeout  # 1 second between spawns

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	
	# Random spawn point
	var spawn = spawn_points[randi() % spawn_points.size()]
	enemy.global_position = spawn.global_position
	
	# Get path to goal
	var path = NavigationServer3D.map_get_path(
		get_viewport().get_world_3d().get_navigation_map(),
		enemy.global_position,
		goal_marker.global_position,
		true
	)
	
	enemy.set_path(path)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_goal.connect(_on_enemy_reached_goal)
	
	get_node("/root/World/Enemies").add_child(enemy)
	enemies_alive += 1

func _on_enemy_died():
	enemies_alive -= 1
	check_wave_complete()

func _on_enemy_reached_goal():
	enemies_alive -= 1
	# Reduce player lives here
	check_wave_complete()

func check_wave_complete():
	if enemies_alive == 0:
		wave_completed.emit(current_wave)

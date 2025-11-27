# enemy_spawner.gd
extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var base_enemies_per_wave: int = 10
@export var spawn_position: Node3D
@export var delay_between_waves: float = 5.0
@export var max_waves: int = 0  # 0 = infinite waves

# Wave scaling configuration
@export_group("Wave Scaling")
@export var enemies_per_wave_increase: int = 2  # Additional enemies each wave
@export var health_multiplier_per_wave: float = 0.2  # 20% more health each wave
@export var gold_multiplier_per_wave: float = 0.15  # 15% more gold each wave
@export var speed_multiplier_per_wave: float = 0.05  # 5% faster each wave

var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var is_ready: bool = false
var is_spawning: bool = false
var is_waiting_for_next_wave: bool = false

signal wave_started(wave_number: int)
signal wave_spawning_complete(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_complete

func _ready():
	if !spawn_position:
		spawn_position = self
	await get_tree().process_frame
	is_ready = true
	
	# Auto-start first wave
	start_next_wave()

func _process(delta: float):
	if !is_ready or !is_spawning:
		return
	
	var enemies_this_wave = get_enemies_for_wave(current_wave)
	if enemies_spawned_this_wave >= enemies_this_wave:
		return
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_enemy()
		spawn_timer = 0.0

func start_next_wave():
	# Check if we've hit the wave limit
	if max_waves > 0 and current_wave >= max_waves:
		all_waves_complete.emit()
		print("All waves complete!")
		return
	
	current_wave += 1
	enemies_spawned_this_wave = 0
	is_spawning = true
	is_waiting_for_next_wave = false
	
	# Update GameManager
	GameManager.current_wave = current_wave
	
	wave_started.emit(current_wave)
	print("Wave %d started! Enemies: %d" % [current_wave, get_enemies_for_wave(current_wave)])

func get_enemies_for_wave(wave: int) -> int:
	return base_enemies_per_wave + ((wave - 1) * enemies_per_wave_increase)

func get_wave_stats(wave: int) -> Dictionary:
	# Calculate scaling multipliers based on wave number
	var wave_index = wave - 1  # Wave 1 = no bonus
	return {
		"health_multiplier": 1.0 + (wave_index * health_multiplier_per_wave),
		"gold_multiplier": 1.0 + (wave_index * gold_multiplier_per_wave),
		"speed_multiplier": 1.0 + (wave_index * speed_multiplier_per_wave),
	}

func spawn_enemy():
	if !enemy_scene:
		push_error("No enemy scene assigned to spawner")
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.add_to_group("enemies")
	
	# Apply wave scaling
	var stats = get_wave_stats(current_wave)
	apply_wave_scaling(enemy, stats)
	
	# Connect signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	
	# Add to scene FIRST (required before setting global_position)
	var level = get_tree().get_first_node_in_group("level")
	if level and level.has_node("Enemies"):
		level.get_node("Enemies").add_child(enemy)
	else:
		push_error("Could not find Enemies node in level")
		enemy.queue_free()  # Clean up the orphaned node
		return
	
	# NOW set global_position (node is in tree)
	enemy.global_position = spawn_position.global_position
	
	enemies_spawned_this_wave += 1
	enemies_alive += 1
	
	var enemies_this_wave = get_enemies_for_wave(current_wave)
	if enemies_spawned_this_wave >= enemies_this_wave:
		is_spawning = false
		wave_spawning_complete.emit(current_wave)
		print("Wave %d spawning complete. Waiting for enemies to be cleared..." % current_wave)

func apply_wave_scaling(enemy: CharacterBody3D, stats: Dictionary):
	# Scale health
	enemy.max_health *= stats.health_multiplier
	enemy.current_health = enemy.max_health
	
	# Scale gold reward
	enemy.gold_reward = int(enemy.gold_reward * stats.gold_multiplier)
	
	# Scale speed
	enemy.speed *= stats.speed_multiplier

func _on_enemy_died(enemy: CharacterBody3D):
	GameManager.add_gold(enemy.gold_reward)
	enemies_alive -= 1
	print("Enemy died! Gold: %d | Remaining: %d" % [enemy.gold_reward, enemies_alive])
	check_wave_cleared()

func _on_enemy_reached_end(enemy: CharacterBody3D):
	GameManager.lose_life()
	enemies_alive -= 1
	print("Enemy reached end! Lives: %d | Remaining: %d" % [GameManager.lives, enemies_alive])
	check_wave_cleared()

func check_wave_cleared():
	# Only check if we're done spawning and all enemies are gone
	if is_spawning or is_waiting_for_next_wave:
		return
	
	if enemies_alive <= 0:
		wave_cleared.emit(current_wave)
		GameManager.add_gold(current_wave * 100)
		print("Wave %d cleared!" % current_wave)
		
		# Start countdown to next wave
		is_waiting_for_next_wave = true
		start_wave_countdown()

func start_wave_countdown():
	print("Next wave in %.1f seconds..." % delay_between_waves)
	
	# Create a timer for the delay
	var timer = get_tree().create_timer(delay_between_waves)
	timer.timeout.connect(start_next_wave)

# Manual wave control methods (useful for UI buttons or debugging)
func force_start_wave():
	if is_waiting_for_next_wave:
		start_next_wave()

func skip_to_wave(wave_number: int):
	current_wave = wave_number - 1  # Will be incremented in start_next_wave
	enemies_alive = 0
	is_spawning = false
	start_next_wave()

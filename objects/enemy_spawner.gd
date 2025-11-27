# enemy_spawner.gd
extends Node3D

@export var enemy_scene: PackedScene  # Basic enemy (tomato)
@export var broccoli_scene: PackedScene  # Strong enemy (broccoli)
@export var boss_scene: PackedScene  # Boss enemy (carrot)
@export var spawn_interval: float = 2.0
@export var base_enemies_per_wave: int = 10
@export var spawn_position: Node3D
@export var delay_between_waves: float = 5.0
@export var max_waves: int = 20  # Set to 0 for infinite waves

# Wave scaling configuration
@export_group("Wave Scaling")
@export var enemies_per_wave_increase: int = 2  # Additional enemies each wave
@export var health_multiplier_per_wave: float = 0.2  # 20% more health each wave
@export var gold_multiplier_per_wave: float = 0.15  # 15% more gold each wave
@export var speed_multiplier_per_wave: float = 0.05  # 5% faster each wave

# Enemy variety configuration
@export_group("Enemy Variety")
@export var broccoli_start_wave: int = 3  # Wave when broccoli starts appearing
@export var broccoli_chance_base: float = 0.2  # 20% chance at start
@export var broccoli_chance_per_wave: float = 0.05  # +5% per wave after start

# Boss configuration
@export_group("Boss Waves")
@export var boss_wave_interval: int = 5  # Boss appears every 5 waves
@export var boss_health_multiplier: float = 1.5  # Boss gets even stronger each appearance

var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var is_ready: bool = false
var is_spawning: bool = false
var is_waiting_for_next_wave: bool = false
var boss_spawned_this_wave: bool = false

signal wave_started(wave_number: int)
signal wave_spawning_complete(wave_number: int)
signal wave_cleared(wave_number: int)
signal all_waves_complete

func _ready():
	if !spawn_position:
		spawn_position = self
	
	# Auto-load enemy scenes if not assigned
	if !broccoli_scene:
		broccoli_scene = load("res://objects/broccoli_enemy.tscn")
	if !boss_scene:
		boss_scene = load("res://objects/carrot_boss.tscn")
	
	await get_tree().process_frame
	is_ready = true
	
	# Auto-start first wave
	start_next_wave()

func _process(delta: float):
	if !is_ready or !is_spawning:
		return
	
	var enemies_this_wave = get_enemies_for_wave(current_wave)
	var is_boss = is_boss_wave(current_wave)
	
	# Check if we're done spawning regular enemies
	if enemies_spawned_this_wave >= enemies_this_wave:
		# If it's a boss wave and boss hasn't spawned, spawn the boss now
		if is_boss and !boss_spawned_this_wave:
			spawn_boss()
		return
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_enemy()
		spawn_timer = 0.0

func start_next_wave():
	# Check if we've hit the wave limit
	if max_waves > 0 and current_wave >= max_waves:
		all_waves_complete.emit()
		GameManager.victory()  # Trigger victory screen
		print("All waves complete!")
		return
	
	current_wave += 1
	enemies_spawned_this_wave = 0
	boss_spawned_this_wave = false
	is_spawning = true
	is_waiting_for_next_wave = false
	
	# Update GameManager
	GameManager.current_wave = current_wave
	
	var is_boss_wave = is_boss_wave(current_wave)
	wave_started.emit(current_wave)
	if is_boss_wave:
		print("⚠️ BOSS WAVE %d started! Enemies: %d + BOSS" % [current_wave, get_enemies_for_wave(current_wave)])
	else:
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

func get_broccoli_chance() -> float:
	if current_wave < broccoli_start_wave:
		return 0.0
	var waves_since_start = current_wave - broccoli_start_wave
	return min(broccoli_chance_base + (waves_since_start * broccoli_chance_per_wave), 0.7)  # Cap at 70%

func is_boss_wave(wave: int) -> bool:
	return wave > 0 and wave % boss_wave_interval == 0

func get_boss_stats_multiplier() -> float:
	# Boss gets stronger each time it appears
	var boss_appearance = current_wave / boss_wave_interval
	return 1.0 + ((boss_appearance - 1) * (boss_health_multiplier - 1.0))

func choose_enemy_scene() -> PackedScene:
	# Determine which enemy type to spawn
	if broccoli_scene and randf() < get_broccoli_chance():
		return broccoli_scene
	return enemy_scene

func spawn_enemy():
	var enemies_this_wave = get_enemies_for_wave(current_wave)
	var is_boss = is_boss_wave(current_wave)
	
	# Check if we should spawn the boss (after all regular enemies)
	if is_boss and enemies_spawned_this_wave >= enemies_this_wave and !boss_spawned_this_wave:
		spawn_boss()
		return
	
	# Regular enemy spawning
	var scene_to_spawn = choose_enemy_scene()
	if !scene_to_spawn:
		push_error("No enemy scene available to spawn")
		return
	
	var enemy = scene_to_spawn.instantiate()
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
	
	# Check if regular spawning is complete
	if enemies_spawned_this_wave >= enemies_this_wave:
		if is_boss and !boss_spawned_this_wave:
			# Boss wave - don't mark complete until boss is spawned
			pass
		else:
			is_spawning = false
			wave_spawning_complete.emit(current_wave)
			print("Wave %d spawning complete. Waiting for enemies to be cleared..." % current_wave)

func spawn_boss():
	if !boss_scene:
		push_error("No boss scene assigned!")
		return
	
	var boss = boss_scene.instantiate()
	boss.add_to_group("enemies")
	boss.add_to_group("boss")  # Extra group for boss-specific logic
	
	# Apply wave scaling plus boss multiplier
	var stats = get_wave_stats(current_wave)
	var boss_multiplier = get_boss_stats_multiplier()
	stats.health_multiplier *= boss_multiplier
	stats.gold_multiplier *= boss_multiplier
	apply_wave_scaling(boss, stats)
	
	# Connect signals
	boss.enemy_died.connect(_on_enemy_died)
	boss.enemy_reached_end.connect(_on_enemy_reached_end)
	
	# Add to scene
	var level = get_tree().get_first_node_in_group("level")
	if level and level.has_node("Enemies"):
		level.get_node("Enemies").add_child(boss)
	else:
		push_error("Could not find Enemies node in level")
		boss.queue_free()
		return
	
	boss.global_position = spawn_position.global_position
	
	boss_spawned_this_wave = true
	enemies_alive += 1
	
	print("🥕 BOSS SPAWNED! Health: %.0f | Gold: %d" % [boss.max_health, boss.gold_reward])
	
	# Now wave spawning is truly complete
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

extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var enemies_per_wave: int = 10
@export var spawn_position: Node3D

var enemies_spawned: int = 0
var spawn_timer: float = 0.0
var is_ready: bool = false  # Add this flag

signal wave_complete

func _ready():
	if !spawn_position:
		spawn_position = self  # Use self as spawn point if none provided
	# Wait one frame to ensure everything is in the tree
	await get_tree().process_frame
	is_ready = true


func _process(delta):
	if !is_ready:  # Check if ready before processing
		return
		
	if enemies_spawned >= enemies_per_wave:
		return
	
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_enemy()
		spawn_timer = 0.0

func spawn_enemy():
	if !enemy_scene:
		push_error("No enemy scene assigned to spawner")
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position.global_position
	
	# Add to enemies group
	enemy.add_to_group("enemies")
	
	# Connect signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	
	# Add to scene
	var level = get_tree().get_first_node_in_group("level")
	if level and level.has_node("Enemies"):
		level.get_node("Enemies").add_child(enemy)
	else:
		push_error("Could not find Enemies node in level")	
	
	enemies_spawned += 1
	
	if enemies_spawned >= enemies_per_wave:
		wave_complete.emit()

func _on_enemy_died(enemy):
	GameManager.add_gold(enemy.gold_reward)
	print("Enemy died!")
	# Award resources, etc.

func _on_enemy_reached_end(enemy):
	GameManager.lose_life()
	print("Enemy reached end! Player takes damage")
	# Reduce player health

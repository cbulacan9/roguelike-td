extends CharacterBody3D

@export var gold_reward: int = 10
@export var speed: float = 3.0
@export var max_health: float = 100.0
var current_health: float

var stuck_timer: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var stuck_threshold: float = 2.0  # Seconds before considered stuck

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

# Accessible by GameManager classes
signal enemy_died(enemy: CharacterBody3D)
signal enemy_reached_end(enemy: CharacterBody3D)

func _ready():
	current_health = max_health
	
	# Configure navigation agent for better pathfinding
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.radius = 0.5  # Matches baked agent radius
	navigation_agent.height = 2.0
	navigation_agent.max_speed = speed
	
	# Configure navigation agent
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.avoidance_enabled = true
	
	# Path settings
	navigation_agent.path_max_distance = 3.0  # How far ahead to look
	
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Wait for navigation to be ready
	call_deferred("setup_navigation")

func setup_navigation():
	# Set target after navigation map is ready
	await get_tree().physics_frame
	set_target_position(get_target_from_level())

func set_target_position(target: Vector3):
	navigation_agent.target_position = target

func _physics_process(delta):
	if navigation_agent.is_navigation_finished():
		# Enemy reached the end
		enemy_reached_end.emit(self)
		queue_free()
		return
	
	# Check if we have a valid path
	if navigation_agent.is_target_reachable():
		var next_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_position)
		
		var desired_velocity = direction * speed
		
		# Use avoidance if enabled
		if navigation_agent.avoidance_enabled:
			navigation_agent.set_velocity(desired_velocity)
		else:
			velocity = desired_velocity
			move_and_slide()
	else:
		# Target not reachable - try to recalculate path
		navigation_agent.target_position = get_target_from_level()
	
	# Stuck detection
	if global_position.distance_to(last_position) < 0.1:
		stuck_timer += delta
		if stuck_timer > stuck_threshold:
			# We're stuck! Try to recover
			recover_from_stuck()
	else:
		stuck_timer = 0.0
		last_position = global_position

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func take_damage(amount: float):
	current_health -= amount
	
	if current_health <= 0:
		die()

func die():
	enemy_died.emit(self)
	queue_free()

func get_target_from_level() -> Vector3:
	# Get the level root
	var level = get_tree().current_scene.get_node("World").get_node("PathManager")
	
	# Try to find EndPoint
	if level.has_node("EndPoint"):
		return level.get_node("EndPoint").global_position
	
	# Fallback
	push_warning("EndPoint not found in level!")
	return global_position + Vector3.FORWARD * 20

func recover_from_stuck():
	print("Enemy stuck, attempting recovery...")
	stuck_timer = 0.0
	
	# Try to push away from current position
	var random_offset = Vector3(
		randf_range(-2.0, 2.0),
		0,
		randf_range(-2.0, 2.0)
	)
	
	global_position += random_offset
	
	# Recalculate path
	navigation_agent.target_position = get_target_from_level()

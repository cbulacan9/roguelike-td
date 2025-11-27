# enemy.gd - Improved pathfinding with proactive rerouting
extends CharacterBody3D

@export var gold_reward: int = 10
@export var speed: float = 3.0
@export var max_health: float = 100.0
var current_health: float

# Path monitoring
var path_check_timer: float = 0.0
var path_check_interval: float = 0.5  # Check path validity every 0.5 seconds
var last_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var stuck_threshold: float = 1.0  # Reduced from 2.0 for faster detection
var minimum_progress: float = 0.3  # Must move at least this far per stuck_threshold

# Navigation state
var navigation_ready: bool = false
var target_position: Vector3 = Vector3.ZERO

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model

# Animation settings
@export_group("Animation")
@export var bounce_height: float = 0.15
@export var bounce_speed: float = 12.0
@export var squash_amount: float = 0.08
var base_model_scale: Vector3 = Vector3(0.8, 0.8, 0.8)  # Match scene scale
var animation_time: float = 0.0

signal enemy_died(enemy: CharacterBody3D)
signal enemy_reached_end(enemy: CharacterBody3D)

func _ready():
	if current_health <= 0:
		current_health = max_health
	
	# Configure navigation agent
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 1.5  # Don't trigger "finished" too early
	navigation_agent.radius = 0.5  # Match NavigationMesh agent_radius
	navigation_agent.height = 2.0
	navigation_agent.max_speed = speed
	
	# Enable avoidance for dynamic obstacle handling
	navigation_agent.avoidance_enabled = true
	navigation_agent.avoidance_priority = 0.5
	
	# More responsive path updates
	navigation_agent.path_max_distance = 2.0
	
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	navigation_agent.path_changed.connect(_on_path_changed)
	
	call_deferred("setup_navigation")

func setup_navigation():
	# Wait for navigation map to be ready
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Get and store the target
	target_position = get_target_from_level()
	
	# Set the target on the navigation agent
	navigation_agent.target_position = target_position
	
	# Wait one more frame for path calculation
	await get_tree().physics_frame
	
	last_position = global_position
	navigation_ready = true
	
	print("Enemy navigation ready. Start: ", global_position, " Target: ", target_position)

func set_target_position(target: Vector3):
	target_position = target
	navigation_agent.target_position = target

func _process(delta: float) -> void:
	# Procedural march animation
	if not model:
		return
	
	# Only animate when moving
	if velocity.length() > 0.1:
		animation_time += delta * bounce_speed
		
		# Bounce up and down (use abs(sin) for a hop effect)
		var bounce = abs(sin(animation_time)) * bounce_height
		model.position.y = bounce
		
		# Squash and stretch
		var squash = 1.0 + sin(animation_time * 2.0) * squash_amount
		model.scale = Vector3(
			base_model_scale.x / squash,
			base_model_scale.y * squash,
			base_model_scale.z / squash
		)
		
		# Face movement direction
		# Note: Adding PI because the tomato model has negative X/Z scale in the scene,
		# which flips its facing direction 180 degrees
		var flat_velocity = Vector3(velocity.x, 0, velocity.z)
		if flat_velocity.length() > 0.1:
			var target_angle = atan2(flat_velocity.x, flat_velocity.z) + PI
			var current_angle = model.rotation.y
			model.rotation.y = lerp_angle(current_angle, target_angle, delta * 10.0)
	else:
		# Idle - gentle settle back to rest
		model.position.y = lerp(model.position.y, 0.0, delta * 5.0)
		model.scale = model.scale.lerp(base_model_scale, delta * 5.0)

func _physics_process(delta):
	# Don't process until navigation is set up
	if not navigation_ready:
		return
	
	# Check if we've actually reached the goal (distance-based, not navigation_finished)
	var distance_to_goal = global_position.distance_to(target_position)
	if distance_to_goal < 2.0:
		print("Enemy reached goal! Distance: ", distance_to_goal)
		enemy_reached_end.emit(self)
		queue_free()
		return
	
	# Periodic path validity check
	path_check_timer += delta
	if path_check_timer >= path_check_interval:
		path_check_timer = 0.0
		check_path_validity()
	
	# Movement
	if navigation_agent.is_target_reachable():
		var next_position = navigation_agent.get_next_path_position()
		var direction = global_position.direction_to(next_position)
		
		# Only move horizontally
		direction.y = 0
		if direction.length() > 0.01:
			direction = direction.normalized()
			var desired_velocity = direction * speed
			
			if navigation_agent.avoidance_enabled:
				navigation_agent.set_velocity(desired_velocity)
			else:
				velocity = desired_velocity
				move_and_slide()
	else:
		# Target not reachable - force recalculation
		request_new_path()
	
	# Stuck detection with progress check
	update_stuck_detection(delta)

func check_path_validity():
	# Check if our current path is still valid
	if not navigation_agent.is_target_reachable():
		request_new_path()
		return
	
	# Check if path distance is reasonable compared to direct distance
	var current_distance = navigation_agent.distance_to_target()
	var direct_distance = global_position.distance_to(target_position)
	
	# If our path is significantly longer than direct distance, recalculate
	if direct_distance > 1.0 and current_distance > direct_distance * 2.5:
		request_new_path()

func update_stuck_detection(delta: float):
	var distance_moved = global_position.distance_to(last_position)
	
	if distance_moved < minimum_progress:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			recover_from_stuck()
	else:
		stuck_timer = 0.0
		last_position = global_position

func request_new_path():
	# Force a complete path recalculation
	if not navigation_ready:
		return
	
	target_position = get_target_from_level()
	navigation_agent.target_position = target_position
	print("Enemy requesting new path to: ", target_position)

func recover_from_stuck():
	print("Enemy stuck at ", global_position, " - attempting recovery")
	stuck_timer = 0.0
	
	# Try small nudges in different directions to find navigable space
	var nudge_directions = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1),
		Vector3(1, 0, 1).normalized(),
		Vector3(-1, 0, -1).normalized(),
	]
	
	var nav_map = navigation_agent.get_navigation_map()
	
	for dir in nudge_directions:
		var test_pos = global_position + dir * 1.5
		var closest_point = NavigationServer3D.map_get_closest_point(nav_map, test_pos)
		
		# Check if this point is on the navmesh and different from current
		if closest_point.distance_to(test_pos) < 0.5 and closest_point.distance_to(global_position) > 0.5:
			global_position = closest_point
			last_position = global_position
			request_new_path()
			return
	
	# Last resort: teleport to closest navigable point
	var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	if closest.distance_to(global_position) > 0.1:
		global_position = closest
		last_position = global_position
	
	request_new_path()

func _on_velocity_computed(safe_velocity: Vector3):
	velocity = safe_velocity
	move_and_slide()

func _on_path_changed():
	# Path was recalculated - reset stuck detection
	stuck_timer = 0.0
	last_position = global_position

func take_damage(amount: float):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	enemy_died.emit(self)
	queue_free()

func get_target_from_level() -> Vector3:
	var path_manager = get_tree().current_scene.get_node_or_null("World/PathManager")
	
	if path_manager and path_manager.has_node("EndPoint"):
		return path_manager.get_node("EndPoint").global_position
	
	push_warning("EndPoint not found in level!")
	return global_position + Vector3.FORWARD * 20

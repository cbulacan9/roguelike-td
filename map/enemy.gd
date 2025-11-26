# enemy.gd
extends CharacterBody3D
class_name Enemy

@export var speed: float = 3.0
@export var health: float = 100.0

var path: PackedVector3Array = []
var current_path_index: int = 0

func set_path(new_path: PackedVector3Array):
	path = new_path
	current_path_index = 0

func _physics_process(delta):
	if path.is_empty() or current_path_index >= path.size():
		return
	
	var target = path[current_path_index]
	var direction = (target - global_position).normalized()
	
	# Move towards target
	velocity = direction * speed
	move_and_slide()
	
	# Check if we reached the current waypoint
	if global_position.distance_to(target) < 0.5:
		current_path_index += 1
		
		# Reached the goal
		if current_path_index >= path.size():
			reached_goal()

func reached_goal():
	# Enemy reached the goal - reduce player lives, etc.
	queue_free()

func take_damage(amount: float):
	health -= amount
	if health <= 0:
		die()

func die():
	# Drop resources, play effects, etc.
	queue_free()

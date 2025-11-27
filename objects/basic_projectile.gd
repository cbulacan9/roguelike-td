extends Node3D

@export var speed: float = 20.0
@export var damage: float = 25.0

var target: CharacterBody3D = null
var velocity: Vector3 = Vector3.ZERO

func _ready():
	# Auto-destroy after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _process(delta):
	if !target or !is_instance_valid(target):
		queue_free()
		return
	
	var direction = global_position.direction_to(target.global_position)
	velocity = direction * speed
	global_position += velocity * delta
	
	# Check if hit target
	if global_position.distance_to(target.global_position) < 0.5:
		hit_target()

func hit_target():
	if target and is_instance_valid(target):
		target.take_damage(damage)
	queue_free()

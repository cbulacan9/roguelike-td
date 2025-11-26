extends CharacterBody3D

@export var max_health := 20.0
@export var move_speed := 5.0

var health := max_health
var reward := 10.0
var special_trait := "Regenerates 2 HP per second"
var gravity := 10.0
var speed = 5.0
var jump_velocity = 4.5

signal died(reward: float)

func _ready():
	# Initialization
	pass

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Get input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# Apply movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Apply movement
	move_and_slide()

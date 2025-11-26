# camera_controller.gd
extends Camera3D

@export var camera_height: float = 20.0
@export var camera_angle: float = -60.0
@export var camera_distance: float = 15.0
@export var move_speed: float = 10.0
@export var zoom_speed: float = 2.0

func _ready():
	# Position camera for tower defense view
	rotation_degrees.x = camera_angle
	position = Vector3(0, camera_height, camera_distance)
	look_at(Vector3.ZERO, Vector3.UP)

func _process(delta):
	# Optional: Camera movement with WASD or arrow keys
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var move_dir = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	position += move_dir * move_speed * delta
	
	# Optional: Zoom with mouse wheel
	if Input.is_action_just_pressed("ui_page_up"):
		position.y = clamp(position.y - zoom_speed, 10, 50)
	if Input.is_action_just_pressed("ui_page_down"):
		position.y = clamp(position.y + zoom_speed, 10, 50)

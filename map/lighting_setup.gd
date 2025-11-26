# lighting_setup.gd
extends Node3D

func _ready():
	setup_directional_light()
	setup_environment()

func setup_directional_light():
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	
	# Position and angle
	sun.rotation_degrees = Vector3(-45, -30, 0)  # Angled down and from the side
	
	# Light properties
	sun.light_energy = 1.0  # Brightness (0.8-1.2 is typical)
	sun.light_color = Color(1.0, 0.98, 0.95)  # Slightly warm white
	
	# Shadow settings - IMPORTANT for performance
	sun.shadow_enabled = true
	sun.shadow_bias = 0.1  # Prevents shadow acne
	sun.shadow_normal_bias = 1.0
	
	# Shadow quality vs performance tradeoff
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0  # Only cast shadows within this range
	
	add_child(sun)

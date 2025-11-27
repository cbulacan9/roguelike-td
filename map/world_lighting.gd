# world_lighting.gd
extends Node3D

@export var enable_shadows: bool = true
@export var shadow_quality: int = 2048
@export var enable_glow: bool = false
@export var enable_fog: bool = false

func _ready():
	setup_sun()
	setup_environment()
	
	if enable_glow:
		add_glow()
	
	if enable_fog:
		add_fog()

func setup_sun():
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	
	# Angle for good tower defense view
	sun.rotation_degrees = Vector3(-50, -30, 0)
	
	# Light properties - warm cartoon kitchen lighting
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)  # Warm yellow tint
	
	# Shadows
	sun.shadow_enabled = enable_shadows
	if enable_shadows:
		sun.shadow_bias = 0.1
		sun.shadow_normal_bias = 1.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 60.0
		sun.directional_shadow_fade_start = 0.8
	
	add_child(sun)
	print("✓ Sun created")

func setup_environment():
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	
	var environment = Environment.new()
	
	# Sky
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.95)
	sky_material.sky_horizon_color = Color(0.65, 0.75, 0.85)
	sky_material.ground_bottom_color = Color(0.2, 0.25, 0.2)
	sky_material.ground_horizon_color = Color(0.4, 0.45, 0.4)
	sky.sky_material = sky_material
	
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	
	# Ambient lighting - brighter for cartoon look
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.88, 0.8)  # Warm ambient
	environment.ambient_light_energy = 0.7
	
	# Tone mapping
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	
	# Anti-aliasing
	#environment.ssaa_mode = Environment.SSAA_MODE_DISABLED  # Use TAA instead for better performance
	
	world_env.environment = environment
	add_child(world_env)
	print("✓ Environment created")

func add_glow():
	var environment = $WorldEnvironment.environment
	
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	environment.glow_strength = 0.8
	environment.glow_bloom = 0.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	print("✓ Glow enabled")

func add_fog():
	var environment = $WorldEnvironment.environment
	
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.7, 0.8, 0.9)
	environment.fog_density = 0.005
	environment.fog_aerial_perspective = 0.5
	
	print("✓ Fog enabled")

# Add to world_lighting.gd
func _input(event):
	if event.is_action_pressed("ui_page_up"):
		adjust_sun_angle(5)
	if event.is_action_pressed("ui_page_down"):
		adjust_sun_angle(-5)
	if event.is_action_pressed("ui_home"):
		toggle_shadows()

func adjust_sun_angle(degrees: float):
	var sun = $Sun
	sun.rotation_degrees.x += degrees
	print("Sun angle: ", sun.rotation_degrees)

func toggle_shadows():
	var sun = $Sun
	sun.shadow_enabled = not sun.shadow_enabled
	print("Shadows: ", "ON" if sun.shadow_enabled else "OFF")

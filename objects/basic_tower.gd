extends Node3D

@export var attack_range: float = 10.0
@export var attack_damage: float = 25.0
@export var attack_rate: float = 1.0  # Attacks per second
@export var projectile_scene: PackedScene  # Optional: for projectile-based towers

# Tower metadata (set by placement manager)
var tower_data: TowerData = null
var grid_position: Vector2i = Vector2i(-1, -1)
var is_selected: bool = false

var attack_timer: float = 0.0
var current_target: CharacterBody3D = null
var selection_indicator: MeshInstance3D = null
var range_indicator: MeshInstance3D = null

@onready var range_area: Area3D = $RangeArea3D
@onready var projectile_spawn: Marker3D = $ToasterModel/ProjectileSpawn

func _ready():
	setup_range_area()
	range_area.body_entered.connect(_on_body_entered_range)
	range_area.body_exited.connect(_on_body_exited_range)

func setup_range_area():
	# Create a sphere collision shape for attack range
	if !range_area:
		range_area = Area3D.new()
		add_child(range_area)
		range_area.name = "RangeArea3D"
	
	var collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = attack_range
	collision_shape.shape = shape
	range_area.add_child(collision_shape)
	
	# Set collision layers
	range_area.collision_layer = 0
	range_area.collision_mask = 2  # Assuming enemies are on layer 2

func _process(delta):
	attack_timer += delta
	
	# Find and attack target
	if !current_target or !is_instance_valid(current_target):
		find_new_target()
	
	if current_target:
		look_at_target()
		
		if attack_timer >= (1.0 / attack_rate):
			attack_target()
			attack_timer = 0.0

func find_new_target():
	current_target = null
	var enemies_in_range = range_area.get_overlapping_bodies()
	
	if enemies_in_range.is_empty():
		return
	
	# Target closest enemy (or use other strategies)
	var closest_distance = INF
	for enemy in enemies_in_range:
		if enemy.is_in_group("enemies"):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				current_target = enemy

func look_at_target():
	if current_target:
		# Rotate tower to face target
		var target_pos = current_target.global_position
		target_pos.y = global_position.y  # Keep tower upright
		look_at(target_pos, Vector3.UP)

func attack_target():
	if !current_target:
		return
	
	if projectile_scene:
		spawn_projectile()
	else:
		# Instant hit
		current_target.take_damage(attack_damage)

func spawn_projectile():
	var projectile = projectile_scene.instantiate()
	
	# Set non-global properties before adding to tree
	projectile.target = current_target
	projectile.damage = attack_damage
	
	# Add to scene tree FIRST (required before setting global_position)
	var level = get_tree().get_first_node_in_group("level")
	if level:
		level.add_child(projectile)
	else:
		get_tree().root.add_child(projectile)
	
	# NOW set global_position (node is in tree)
	if projectile_spawn:
		projectile.global_position = projectile_spawn.global_position
	else:
		projectile.global_position = global_position + Vector3.UP * 1.8

func _on_body_entered_range(body):
	if body.is_in_group("enemies") and !current_target:
		current_target = body

func _on_body_exited_range(body):
	if body == current_target:
		current_target = null

# Selection system
func select() -> void:
	is_selected = true
	_show_selection_indicator()
	_show_range_indicator()

func deselect() -> void:
	is_selected = false
	_hide_selection_indicator()
	_hide_range_indicator()

func _show_selection_indicator() -> void:
	if selection_indicator:
		selection_indicator.visible = true
		return
	
	# Create a ring/circle indicator below the tower
	selection_indicator = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 16
	torus.ring_segments = 16
	selection_indicator.mesh = torus
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.2, 0.8)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.9, 0.2)
	material.emission_energy_multiplier = 0.5
	selection_indicator.material_override = material
	
	selection_indicator.position = Vector3(0, 0.1, 0)
	selection_indicator.rotation_degrees.x = 90  # Lay flat
	add_child(selection_indicator)

func _hide_selection_indicator() -> void:
	if selection_indicator:
		selection_indicator.visible = false

func _show_range_indicator() -> void:
	if range_indicator:
		range_indicator.visible = true
		return
	
	# Create a flat circle to show attack range
	range_indicator = MeshInstance3D.new()
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = attack_range
	circle_mesh.bottom_radius = attack_range
	circle_mesh.height = 0.05
	circle_mesh.radial_segments = 32
	range_indicator.mesh = circle_mesh
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 1.0, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_indicator.material_override = material
	
	range_indicator.position = Vector3(0, 0.1, 0)
	range_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(range_indicator)

func _hide_range_indicator() -> void:
	if range_indicator:
		range_indicator.visible = false

func get_sell_value() -> int:
	if tower_data:
		return tower_data.get_sell_value()
	return 0

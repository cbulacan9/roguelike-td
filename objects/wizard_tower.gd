extends Node3D

@export var attack_range: float = 10.0
@export var attack_damage: float = 25.0
@export var attack_rate: float = 1.0  # Attacks per second
@export var projectile_scene: PackedScene

# Animation settings
@export_group("Cast Animation")
@export var cast_tilt_angle: float = 15.0  # Degrees to tilt back when casting
@export var cast_duration: float = 0.3  # How long the cast animation takes

# Tower metadata (set by placement manager)
var tower_data: TowerData = null
var grid_position: Vector2i = Vector2i(-1, -1)
var is_selected: bool = false

var attack_timer: float = 0.0
var current_target: CharacterBody3D = null
var is_casting: bool = false
var selection_indicator: MeshInstance3D = null
var range_indicator: MeshInstance3D = null

# Node references
@onready var range_area: Area3D = $RangeArea3D
@onready var model: Node3D = $WizardModel
@onready var projectile_spawn: Marker3D = $WizardModel/ProjectileSpawn
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	setup_range_area()
	setup_cast_animation()
	range_area.body_entered.connect(_on_body_entered_range)
	range_area.body_exited.connect(_on_body_exited_range)

func setup_range_area() -> void:
	# Create collision shape for attack range detection
	var collision_shape := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = attack_range
	collision_shape.shape = shape
	range_area.add_child(collision_shape)
	
	# Detect enemies only (layer 2)
	range_area.collision_layer = 0
	range_area.collision_mask = 2

func setup_cast_animation() -> void:
	# Create the cast animation procedurally
	var animation := Animation.new()
	animation.length = cast_duration
	
	# Track for model rotation (tilt back then forward)
	var track_idx := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_idx, "WizardModel:rotation")
	
	# Keyframes: rest -> tilt back -> thrust forward -> rest
	var tilt_rad := deg_to_rad(cast_tilt_angle)
	animation.track_insert_key(track_idx, 0.0, Vector3.ZERO)
	animation.track_insert_key(track_idx, cast_duration * 0.3, Vector3(-tilt_rad, 0, 0))
	animation.track_insert_key(track_idx, cast_duration * 0.5, Vector3(tilt_rad * 0.5, 0, 0))
	animation.track_insert_key(track_idx, cast_duration, Vector3.ZERO)
	
	# Add to animation library
	var library := AnimationLibrary.new()
	library.add_animation("cast", animation)
	
	# Also add an idle sway animation
	var idle_anim := Animation.new()
	idle_anim.length = 2.0
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	
	var idle_track := idle_anim.add_track(Animation.TYPE_VALUE)
	idle_anim.track_set_path(idle_track, "WizardModel:rotation")
	idle_anim.track_insert_key(idle_track, 0.0, Vector3.ZERO)
	idle_anim.track_insert_key(idle_track, 1.0, Vector3(0, 0, deg_to_rad(2.0)))
	idle_anim.track_insert_key(idle_track, 2.0, Vector3.ZERO)
	
	library.add_animation("idle", idle_anim)
	animation_player.add_animation_library("", library)
	
	# Start with idle animation
	animation_player.play("idle")

func _process(delta: float) -> void:
	attack_timer += delta
	
	# Find target if we don't have one
	if !current_target or !is_instance_valid(current_target):
		find_new_target()
	
	if current_target:
		look_at_target()
		
		if attack_timer >= (1.0 / attack_rate) and !is_casting:
			attack_target()
			attack_timer = 0.0

func find_new_target() -> void:
	current_target = null
	var enemies_in_range := range_area.get_overlapping_bodies()
	
	if enemies_in_range.is_empty():
		return
	
	# Target closest enemy
	var closest_distance := INF
	for enemy in enemies_in_range:
		if enemy.is_in_group("enemies"):
			var distance := global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				current_target = enemy

func look_at_target() -> void:
	if current_target and !is_casting:
		var target_pos := current_target.global_position
		target_pos.y = global_position.y  # Stay upright
		look_at(target_pos, Vector3.UP)

func attack_target() -> void:
	if !current_target:
		return
	
	# Play cast animation
	is_casting = true
	animation_player.play("cast")
	
	# Spawn projectile at the peak of the animation
	await get_tree().create_timer(cast_duration * 0.5).timeout
	
	if current_target and is_instance_valid(current_target):
		spawn_projectile()
	
	# Wait for animation to finish
	await animation_player.animation_finished
	is_casting = false
	
	# Resume idle
	if !current_target:
		animation_player.play("idle")

func spawn_projectile() -> void:
	if !projectile_scene:
		# Fallback: instant damage
		if current_target and current_target.has_method("take_damage"):
			current_target.take_damage(attack_damage)
		return
	
	var projectile := projectile_scene.instantiate()
	
	# Spawn from wand tip
	if projectile_spawn:
		projectile.global_position = projectile_spawn.global_position
	else:
		projectile.global_position = global_position + Vector3.UP * 1.5
	
	projectile.target = current_target
	projectile.damage = attack_damage
	
	# Add to level
	var level := get_tree().get_first_node_in_group("level")
	if level:
		level.add_child(projectile)
	else:
		get_tree().root.add_child(projectile)

func _on_body_entered_range(body: Node3D) -> void:
	if body.is_in_group("enemies") and !current_target:
		current_target = body

func _on_body_exited_range(body: Node3D) -> void:
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

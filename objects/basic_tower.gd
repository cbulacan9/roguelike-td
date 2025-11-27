extends Node3D

@export var attack_range: float = 10.0
@export var attack_damage: float = 25.0
@export var attack_rate: float = 1.0  # Attacks per second
@export var projectile_scene: PackedScene  # Optional: for projectile-based towers

var attack_timer: float = 0.0
var current_target: CharacterBody3D = null

@onready var range_area: Area3D = $RangeArea3D

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
	projectile.global_position = global_position + Vector3.UP * 1.0
	projectile.target = current_target
	projectile.damage = attack_damage
	# Add to level instead of root
	var level = get_tree().get_first_node_in_group("level")
	if level:
		level.add_child(projectile)
	else:
		get_tree().root.add_child(projectile)

func _on_body_entered_range(body):
	if body.is_in_group("enemies") and !current_target:
		current_target = body

func _on_body_exited_range(body):
	if body == current_target:
		current_target = null

# tower.gd
extends Node3D

@export var attack_range: float = 5.0
@export var attack_damage: float = 10.0
@export var attack_rate: float = 1.0

var targets_in_range: Array = []
var attack_timer: float = 0.0

func _ready():
	setup_visuals()
	setup_detection()
	setup_navigation_obstacle()

func setup_visuals():
	# Create tower mesh if not in scene
	if not has_node("TowerMesh"):
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "TowerMesh"
		
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.7
		cylinder.height = 3.0
		mesh_instance.mesh = cylinder
		mesh_instance.position.y = 1.5
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.5, 0.5, 0.8)
		mesh_instance.material_override = material
		
		add_child(mesh_instance)

func setup_detection():
	# Create detection area if not in scene
	if not has_node("Area3D"):
		var area = Area3D.new()
		area.name = "Area3D"
		
		var collision = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = attack_range
		collision.shape = sphere
		collision.position.y = 1.5
		
		area.add_child(collision)
		add_child(area)
		
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func setup_navigation_obstacle():
	# Create navigation obstacle if not in scene
	if not has_node("NavigationObstacle3D"):
		var obstacle = NavigationObstacle3D.new()
		obstacle.name = "NavigationObstacle3D"
		obstacle.radius = 0.75
		obstacle.height = 3.0
		add_child(obstacle)

func _process(delta):
	attack_timer += delta
	
	if attack_timer >= 1.0 / attack_rate:
		attack_timer = 0.0
		attack_nearest_enemy()

func attack_nearest_enemy():
	# Clean up invalid references
	targets_in_range = targets_in_range.filter(func(e): return is_instance_valid(e))
	
	if targets_in_range.is_empty():
		return
	
	# Find closest enemy
	var closest = null
	var closest_dist = INF
	
	for enemy in targets_in_range:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest = enemy
			closest_dist = dist
	
	if closest and closest.has_method("take_damage"):
		closest.take_damage(attack_damage)
		print("Tower attacking enemy for ", attack_damage, " damage")

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		targets_in_range.append(body)

func _on_body_exited(body):
	targets_in_range.erase(body)

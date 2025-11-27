# tower_placement_manager.gd
extends Node3D

@export var tower_scene: PackedScene
@export var map_grid: MapGrid
@export var camera: Camera3D
@export var tower_cost: int = 100

var preview_mesh: MeshInstance3D = null
var can_place: bool = false
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var placement_enabled: bool = true

func _ready():
	create_preview_mesh()
	
	if preview_mesh:
		preview_mesh.visible = false

func create_preview_mesh():
	preview_mesh = MeshInstance3D.new()
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.5, 3, 1.5)
	preview_mesh.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_mesh.material_override = material
	
	add_child(preview_mesh)

func _process(_delta):
	if not placement_enabled:
		return
	
	update_preview()

func _input(event):
	if not placement_enabled:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			attempt_place_tower()
		
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_placement_mode(false)

func update_preview():
	var mouse_pos = get_viewport().get_mouse_position()
	var world_pos = get_world_position_from_mouse(mouse_pos)
	
	if world_pos == Vector3.INF:
		preview_mesh.visible = false
		return
	
	preview_mesh.visible = true
	
	var grid_pos = map_grid.world_to_grid(world_pos)
	current_grid_pos = grid_pos
	
	var snapped_world_pos = map_grid.grid_to_world(grid_pos)
	preview_mesh.global_position = snapped_world_pos
	preview_mesh.global_position.y = 1.5
	
	can_place = map_grid.is_valid_build_position(grid_pos) and GameManager.gold >= tower_cost
	
	var material = preview_mesh.material_override as StandardMaterial3D
	if can_place:
		material.albedo_color = Color(0, 1, 0, 0.5)
	else:
		material.albedo_color = Color(1, 0, 0, 0.5)

func get_world_position_from_mouse(mouse_position: Vector2) -> Vector3:
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000
	)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.INF

func attempt_place_tower():
	if not can_place:
		return
	
	if GameManager.gold < tower_cost:
		return
	
	if not tower_scene:
		push_error("Tower scene not assigned!")
		return
	
	# Deduct cost
	GameManager.spend_gold(tower_cost)
	
	# Instantiate tower
	var tower = tower_scene.instantiate()
	
	# Add to scene tree FIRST
	var towers_container = get_node_or_null("/root/World/Towers")
	if towers_container:
		towers_container.add_child(tower)
	else:
		var world = get_node_or_null("/root/World")
		if world:
			world.add_child(tower)
		else:
			get_parent().add_child(tower)
	
	# THEN set position (after tower is in scene tree)
	var world_pos = map_grid.grid_to_world(current_grid_pos)
	tower.global_position = world_pos
	tower.global_position.y = 0
	
	# Mark grid cell as occupied
	map_grid.occupy_cell(current_grid_pos)

func toggle_placement_mode(enabled: bool):
	placement_enabled = enabled
	if preview_mesh:
		preview_mesh.visible = enabled

func add_gold(amount: int):
	GameManager.add_gold(amount)

# tower_placement_manager.gd
extends Node3D

@export var tower_scene: PackedScene  # Assign your tower scene here
@export var map_grid: MapGrid  # Reference to your MapGrid
@export var camera: Camera3D  # Reference to your camera
@export var tower_cost: int = 100

var preview_mesh: MeshInstance3D = null
var can_place: bool = false
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var placement_enabled: bool = true

# Resources (you'll expand this later)
var player_gold: int = 500

func _ready():
	create_preview_mesh()
	
	# Hide preview initially
	if preview_mesh:
		preview_mesh.visible = false

func create_preview_mesh():
	# Create a preview ghost tower
	preview_mesh = MeshInstance3D.new()
	
	# Simple box for preview (replace with your tower mesh later)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.5, 3, 1.5)
	preview_mesh.mesh = box_mesh
	
	# Semi-transparent material
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
	
	# Left click to place tower
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			attempt_place_tower()
		
		# Right click to cancel
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_placement_mode(false)

func update_preview():
	var mouse_pos = get_viewport().get_mouse_position()
	var world_pos = get_world_position_from_mouse(mouse_pos)
	
	if world_pos == Vector3.INF:
		# Mouse not over valid ground
		preview_mesh.visible = false
		return
	
	preview_mesh.visible = true
	
	# Convert to grid position
	var grid_pos = map_grid.world_to_grid(world_pos)
	current_grid_pos = grid_pos
	
	# Snap to grid
	var snapped_world_pos = map_grid.grid_to_world(grid_pos)
	preview_mesh.global_position = snapped_world_pos
	preview_mesh.global_position.y = 1.5  # Half the tower height
	
	# Check if position is valid
	can_place = map_grid.is_valid_build_position(grid_pos) and player_gold >= tower_cost
	
	# Update preview color
	var material = preview_mesh.material_override as StandardMaterial3D
	if can_place:
		material.albedo_color = Color(0, 1, 0, 0.5)  # Green = can place
	else:
		material.albedo_color = Color(1, 0, 0, 0.5)  # Red = cannot place

func get_world_position_from_mouse(mouse_position: Vector2) -> Vector3:
	# Cast ray from camera through mouse position
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_direction = camera.project_ray_normal(mouse_position)
	
	# Raycast to find ground
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000
	)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.INF  # Invalid position

func attempt_place_tower():
	if not can_place:
		print("Cannot place tower here!")
		return
	
	if player_gold < tower_cost:
		print("Not enough gold! Need: ", tower_cost, " Have: ", player_gold)
		return
	
	# Deduct cost
	player_gold -= tower_cost
	print("Gold remaining: ", player_gold)
	
	# Spawn tower
	var tower = tower_scene.instantiate()
	var world_pos = map_grid.grid_to_world(current_grid_pos)
	tower.global_position = world_pos
	tower.global_position.y = 0  # Ground level
	
	# Add to scene (add to Towers container if you have one)
	var towers_container = get_node_or_null("/root/World/Towers")
	if towers_container:
		towers_container.add_child(tower)
	else:
		get_tree().root.get_node("World").add_child(tower)
	
	# Mark grid cell as occupied
	map_grid.occupy_cell(current_grid_pos)
	
	print("Tower placed at grid position: ", current_grid_pos)

func toggle_placement_mode(enabled: bool):
	placement_enabled = enabled
	if preview_mesh:
		preview_mesh.visible = enabled
	
	print("Placement mode: ", "ON" if enabled else "OFF")

func add_gold(amount: int):
	player_gold += amount
	print("Gold added: +", amount, " | Total: ", player_gold)

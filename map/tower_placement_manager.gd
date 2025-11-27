# tower_placement_manager.gd
extends Node3D

@export var map_grid: MapGrid
@export var camera: Camera3D
@export var navigation_region: NavigationRegion3D

var preview_mesh: MeshInstance3D = null
var can_place: bool = false
var current_grid_pos: Vector2i = Vector2i(-1, -1)
var placement_enabled: bool = true

# Track placed towers for selection/selling
var placed_towers: Dictionary = {}  # grid_pos (Vector2i) -> tower node

enum InteractionMode {
	PLACE,    # Placing new towers
	SELECT    # Selecting existing towers
}
var interaction_mode: InteractionMode = InteractionMode.PLACE

signal tower_placed(tower: Node3D, grid_pos: Vector2i)
signal tower_removed(grid_pos: Vector2i)

func _ready() -> void:
	create_preview_mesh()
	
	if preview_mesh:
		preview_mesh.visible = false
	
	GameManager.tower_selected.connect(_on_tower_selected)
	GameManager.tower_sold.connect(_on_tower_sold)
	
	# Auto-find navigation region if not set
	if not navigation_region:
		navigation_region = get_tree().current_scene.get_node_or_null("World/NavigationRegion3D")
		if navigation_region:
			print("Found NavigationRegion3D: ", navigation_region.name)

func create_preview_mesh() -> void:
	preview_mesh = MeshInstance3D.new()
	
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.5, 3, 1.5)
	preview_mesh.mesh = box_mesh
	
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_mesh.material_override = material
	
	add_child(preview_mesh)

func _process(_delta: float) -> void:
	if not placement_enabled:
		return
	
	update_preview()

func _input(event: InputEvent) -> void:
	if is_mouse_over_ui():
		return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if interaction_mode == InteractionMode.PLACE and placement_enabled:
				attempt_place_tower()
			else:
				attempt_select_tower()
		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Right click: deselect any selected tower and disable placement preview
			GameManager.deselect_placed_tower()
			toggle_placement_mode(false)
	
	if event is InputEventKey and event.pressed:
		# ESC to deselect and cancel placement
		if event.keycode == KEY_ESCAPE:
			GameManager.deselect_placed_tower()
			toggle_placement_mode(false)
			return
		
		# Number keys to select tower types
		var key_num := -1
		match event.keycode:
			KEY_1: key_num = 0
			KEY_2: key_num = 1
			KEY_3: key_num = 2
			KEY_4: key_num = 3
			KEY_5: key_num = 4
		
		if key_num >= 0 and key_num < GameManager.tower_types.size():
			# Switch to placement mode when selecting a tower type
			GameManager.deselect_placed_tower()
			GameManager.select_tower(GameManager.tower_types[key_num].id)
			interaction_mode = InteractionMode.PLACE
			toggle_placement_mode(true)

func is_mouse_over_ui() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()
	return hovered_control != null

func update_preview() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var world_pos := get_world_position_from_mouse(mouse_pos)
	
	if world_pos == Vector3.INF:
		preview_mesh.visible = false
		can_place = false
		return
	
	var grid_pos := map_grid.world_to_grid(world_pos)
	current_grid_pos = grid_pos
	
	var is_within_bounds: bool = map_grid.is_valid_build_position(grid_pos)
	
	if not is_within_bounds:
		preview_mesh.visible = false
		can_place = false
		return
	
	preview_mesh.visible = true
	
	var snapped_world_pos := map_grid.grid_to_world(grid_pos)
	preview_mesh.global_position = snapped_world_pos
	preview_mesh.global_position.y = 1.5
	
	can_place = GameManager.can_afford_selected_tower()
	
	var material := preview_mesh.material_override as StandardMaterial3D
	if GameManager.selected_tower:
		if can_place:
			material.albedo_color = GameManager.selected_tower.preview_color
		else:
			material.albedo_color = Color(1, 0, 0, 0.5)
	else:
		material.albedo_color = Color(0.5, 0.5, 0.5, 0.5)

func get_world_position_from_mouse(mouse_position: Vector2) -> Vector3:
	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000
	)
	
	var result := space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.INF

func attempt_place_tower() -> void:
	if not can_place:
		return
	
	var tower_data := GameManager.selected_tower
	if tower_data == null:
		push_error("No tower selected!")
		return
	
	if not GameManager.spend_gold(tower_data.cost):
		return
	
	if not map_grid.is_valid_build_position(current_grid_pos):
		print("Invalid grid position: ", current_grid_pos)
		GameManager.add_gold(tower_data.cost)
		return
	
	if not tower_data.scene:
		push_error("Tower scene not assigned for: " + tower_data.id)
		GameManager.add_gold(tower_data.cost)
		return
	
	# Instantiate tower
	var tower := tower_data.scene.instantiate()
	
	# Add tower to the Towers container under NavigationRegion3D
	# This ensures towers are included when rebaking the navmesh
	var towers_container := get_node_or_null("/root/Main/World/NavigationRegion3D/Towers")
	if towers_container:
		towers_container.add_child(tower)
	elif navigation_region:
		navigation_region.add_child(tower)
	else:
		push_warning("Could not find proper container for tower")
		get_parent().add_child(tower)
	
	# Set position after adding to scene tree
	var world_pos := map_grid.grid_to_world(current_grid_pos)
	tower.global_position = world_pos
	tower.global_position.y = 0
	
	# Store tower metadata for selling
	if "tower_data" in tower:
		tower.tower_data = tower_data
	if "grid_position" in tower:
		tower.grid_position = current_grid_pos
	
	# Track tower in our dictionary
	placed_towers[current_grid_pos] = tower
	
	# Mark grid cell as occupied
	map_grid.occupy_cell(current_grid_pos)
	
	# Rebake navigation mesh to include the new tower as an obstacle
	rebake_navigation_mesh()
	
	tower_placed.emit(tower, current_grid_pos)
	
	print("Placed %s at grid position %s" % [tower_data.display_name, current_grid_pos])

func rebake_navigation_mesh() -> void:
	if not navigation_region:
		push_warning("No NavigationRegion3D found - cannot rebake navmesh")
		return
	
	print("Rebaking navigation mesh...")
	
	# Bake on a background thread (non-blocking)
	navigation_region.bake_navigation_mesh()
	
	# After baking completes, tell enemies to recalculate paths
	# We need to wait for baking to finish
	if not navigation_region.bake_finished.is_connected(_on_navmesh_bake_finished):
		navigation_region.bake_finished.connect(_on_navmesh_bake_finished)

func _on_navmesh_bake_finished() -> void:
	print("Navigation mesh rebake complete - notifying enemies")
	notify_enemies_to_repath()

func notify_enemies_to_repath() -> void:
	var enemies_container = get_node_or_null("/root/Main/World/Enemies")
	if not enemies_container:
		return
	
	for enemy in enemies_container.get_children():
		if enemy.has_method("request_new_path"):
			enemy.request_new_path()

func toggle_placement_mode(enabled: bool) -> void:
	placement_enabled = enabled
	if enabled:
		interaction_mode = InteractionMode.PLACE
	if preview_mesh:
		preview_mesh.visible = enabled

func attempt_select_tower() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var world_pos := get_world_position_from_mouse(mouse_pos)
	
	if world_pos == Vector3.INF:
		# Clicked on nothing - deselect
		GameManager.deselect_placed_tower()
		return
	
	var grid_pos := map_grid.world_to_grid(world_pos)
	
	# Check if there's a tower at this position
	if placed_towers.has(grid_pos):
		var tower: Node3D = placed_towers[grid_pos] as Node3D
		if tower and is_instance_valid(tower):
			GameManager.select_placed_tower(tower)
			print("Selected tower at grid position: ", grid_pos)
		else:
			# Clean up invalid reference
			placed_towers.erase(grid_pos)
			GameManager.deselect_placed_tower()
	else:
		# Clicked on empty space - deselect
		GameManager.deselect_placed_tower()

func _on_tower_sold(tower: Node3D, refund_amount: int) -> void:
	# Find and remove the tower from our tracking
	var grid_pos := Vector2i(-1, -1)
	
	# Get grid position from tower if available
	if "grid_position" in tower:
		grid_pos = tower.grid_position
	else:
		# Search for it in our dictionary
		for pos in placed_towers:
			if placed_towers[pos] == tower:
				grid_pos = pos
				break
	
	if grid_pos != Vector2i(-1, -1):
		# Remove from tracking
		placed_towers.erase(grid_pos)
		
		# Free the grid cell
		map_grid.free_cell(grid_pos)
		
		# Emit our signal
		tower_removed.emit(grid_pos)
		
		print("Sold tower at %s for %d gold" % [grid_pos, refund_amount])
	
	# Destroy the tower and wait for it to be freed before rebaking
	tower.queue_free()
	
	# Wait for the tower to actually be removed from the scene tree
	await get_tree().process_frame
	
	# Now rebake navigation mesh with the tower gone
	rebake_navigation_mesh()

func _on_tower_selected(_tower_data: TowerData) -> void:
	interaction_mode = InteractionMode.PLACE
	toggle_placement_mode(true)

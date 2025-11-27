# map_grid.gd
extends Node3D
class_name MapGrid

@export var grid_size: Vector2i = Vector2i(20, 20)
@export var cell_size: float = 2.0
@export var buildable_area_material: StandardMaterial3D
@export var occupied_material: StandardMaterial3D

var grid_data: Array = []
var cell_meshes: Array = []

enum CellState {
	UNBUILDABLE,
	BUILDABLE,
	OCCUPIED,
	PATH
}

func _ready():
	print("=== MapGrid Initialization ===")
	print("Grid size: ", grid_size)
	print("Cell size: ", cell_size)
	print("MapGrid global position: ", global_position)
	print("=============================")
	
	initialize_grid()
	create_materials_if_needed()
	create_visual_grid()

func initialize_grid():
	grid_data = []
	for x in grid_size.x:
		var row = []
		for y in grid_size.y:
			row.append(CellState.BUILDABLE)
		grid_data.append(row)

func create_materials_if_needed():
	if not buildable_area_material:
		buildable_area_material = StandardMaterial3D.new()
		buildable_area_material.albedo_color = Color(0.3, 0.8, 0.3, 0.3)
		buildable_area_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if not occupied_material:
		occupied_material = StandardMaterial3D.new()
		occupied_material.albedo_color = Color(0.8, 0.2, 0.2, 0.5)
		occupied_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

# FIXED: Returns GLOBAL world position, accounting for MapGrid's own position
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	# Calculate the LOCAL position relative to grid origin
	var half_grid_size = Vector2(grid_size) * cell_size / 2.0
	
	var local_pos = Vector3(
		grid_pos.x * cell_size + cell_size / 2.0 - half_grid_size.x,
		0,
		grid_pos.y * cell_size + cell_size / 2.0 - half_grid_size.y
	)
	
	# Add the MapGrid node's global position to get the true world position
	return global_position + local_pos

# FIXED: Converts world position to grid, accounting for MapGrid's position
func world_to_grid(world_pos: Vector3) -> Vector2i:
	# Convert world position to local position relative to this node
	var local_pos = world_pos - global_position
	
	# Offset by half the grid size to account for centering
	var half_grid_size = Vector2(grid_size) * cell_size / 2.0
	
	var x = int((local_pos.x + half_grid_size.x) / cell_size)
	var z = int((local_pos.z + half_grid_size.y) / cell_size)
	
	return Vector2i(x, z)

func is_valid_build_position(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= grid_size.x:
		return false
	if grid_pos.y < 0 or grid_pos.y >= grid_size.y:
		return false
	return grid_data[grid_pos.x][grid_pos.y] == CellState.BUILDABLE

func occupy_cell(grid_pos: Vector2i):
	if is_valid_build_position(grid_pos):
		grid_data[grid_pos.x][grid_pos.y] = CellState.OCCUPIED
		update_cell_visual(grid_pos)

func free_cell(grid_pos: Vector2i):
	if grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y:
		if grid_data[grid_pos.x][grid_pos.y] == CellState.OCCUPIED:
			grid_data[grid_pos.x][grid_pos.y] = CellState.BUILDABLE
			update_cell_visual(grid_pos)

func update_cell_visual(grid_pos: Vector2i):
	# For visual updates, we use LOCAL positions since meshes are children
	var half_grid_size = Vector2(grid_size) * cell_size / 2.0
	var local_world_pos = Vector3(
		grid_pos.x * cell_size + cell_size / 2.0 - half_grid_size.x,
		0,
		grid_pos.y * cell_size + cell_size / 2.0 - half_grid_size.y
	)
	
	for mesh in cell_meshes:
		if mesh.position.distance_to(local_world_pos) < 0.1:
			match grid_data[grid_pos.x][grid_pos.y]:
				CellState.OCCUPIED:
					mesh.material_override = occupied_material
				CellState.BUILDABLE:
					mesh.material_override = buildable_area_material
				CellState.PATH:
					var path_mat = StandardMaterial3D.new()
					path_mat.albedo_color = Color(0.8, 0.6, 0.3, 0.5)
					path_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mesh.material_override = path_mat
			break

func create_visual_grid():
	# Visual grid uses LOCAL positions since the meshes are children of MapGrid
	for x in grid_size.x:
		for y in grid_size.y:
			if grid_data[x][y] == CellState.BUILDABLE:
				var mesh_instance = MeshInstance3D.new()
				var plane_mesh = PlaneMesh.new()
				plane_mesh.size = Vector2(cell_size * 0.9, cell_size * 0.9)
				mesh_instance.mesh = plane_mesh
				mesh_instance.material_override = buildable_area_material
				
				# Calculate LOCAL position for child mesh
				var half_grid_size = Vector2(grid_size) * cell_size / 2.0
				mesh_instance.position = Vector3(
					x * cell_size + cell_size / 2.0 - half_grid_size.x,
					0.01,
					y * cell_size + cell_size / 2.0 - half_grid_size.y
				)
				
				mesh_instance.name = "GridCell_%d_%d" % [x, y]
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mesh_instance)
				cell_meshes.append(mesh_instance)

func mark_path_cells(path_grid_positions: Array[Vector2i]):
	for pos in path_grid_positions:
		if pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y:
			grid_data[pos.x][pos.y] = CellState.PATH
			update_cell_visual(pos)

## Marks cells within a world-space bounding box as unbuildable
## Used for obstacles like counters, furniture, etc.
func mark_area_unbuildable(world_min: Vector3, world_max: Vector3) -> void:
	# Convert world bounds to grid coordinates
	var grid_min = world_to_grid(world_min)
	var grid_max = world_to_grid(world_max)
	
	# Ensure min/max are correct order
	var x_start = mini(grid_min.x, grid_max.x)
	var x_end = maxi(grid_min.x, grid_max.x)
	var y_start = mini(grid_min.y, grid_max.y)
	var y_end = maxi(grid_min.y, grid_max.y)
	
	print("Marking unbuildable area: grid (", x_start, ",", y_start, ") to (", x_end, ",", y_end, ")")
	
	for x in range(x_start, x_end + 1):
		for y in range(y_start, y_end + 1):
			if x >= 0 and x < grid_size.x and y >= 0 and y < grid_size.y:
				grid_data[x][y] = CellState.UNBUILDABLE
				_hide_cell_visual(Vector2i(x, y))

## Hides the visual indicator for unbuildable cells
func _hide_cell_visual(grid_pos: Vector2i) -> void:
	var half_grid_size = Vector2(grid_size) * cell_size / 2.0
	var local_world_pos = Vector3(
		grid_pos.x * cell_size + cell_size / 2.0 - half_grid_size.x,
		0,
		grid_pos.y * cell_size + cell_size / 2.0 - half_grid_size.y
	)
	
	for mesh in cell_meshes:
		if mesh.position.distance_to(local_world_pos) < 0.1:
			mesh.visible = false
			break

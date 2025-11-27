extends Node3D
## Kitchen environment setup - creates the cartoon kitchen aesthetic
## Builds floor tiles, walls, and decorative elements programmatically

@export var floor_size: Vector2 = Vector2(40, 40)
@export var tile_size: float = 2.0  # Match your grid cell size
@export var wall_height: float = 8.0
@export var counter_depth: float = 4.0
@export var counter_height: float = 2.5

# Colors matching the reference image
const FLOOR_LIGHT_BLUE := Color(0.4, 0.55, 0.75)
const FLOOR_DARK_BLUE := Color(0.2, 0.35, 0.55)
const CABINET_YELLOW := Color(0.85, 0.7, 0.25)
const CABINET_YELLOW_DARK := Color(0.7, 0.55, 0.15)
const WALL_YELLOW := Color(0.95, 0.85, 0.4)
const WALL_PINK := Color(0.9, 0.7, 0.75)
const BACKSPLASH_BLUE := Color(0.5, 0.6, 0.8)
const GROUT_COLOR := Color(0.7, 0.75, 0.8)
const FRIDGE_WHITE := Color(0.95, 0.95, 0.95)
const FRIDGE_SILVER := Color(0.75, 0.78, 0.8)
const STOVE_WHITE := Color(0.92, 0.92, 0.9)
const STOVE_BLACK := Color(0.15, 0.15, 0.15)
const TEAPOT_BLUE := Color(0.2, 0.3, 0.6)
const TEAPOT_PATTERN := Color(0.9, 0.9, 0.95)

var floor_shader: Shader
var floor_material: ShaderMaterial
var map_grid: MapGrid

# Store counter bounds for grid registration
var counter_bounds: Array = []  # Array of {min: Vector3, max: Vector3}

func _ready() -> void:
	_setup_floor_material()
	_create_walls()
	_create_counters()
	_create_decorative_elements()
	
	# Register unbuildable areas with the grid (deferred to ensure grid is ready)
	call_deferred("_register_unbuildable_areas")

func _setup_floor_material() -> void:
	# Load and apply the kitchen floor shader
	floor_shader = load("res://materials/kitchen_floor.gdshader")
	floor_material = ShaderMaterial.new()
	floor_material.shader = floor_shader
	
	# Set shader parameters
	floor_material.set_shader_parameter("tile_color_light", Vector3(FLOOR_LIGHT_BLUE.r, FLOOR_LIGHT_BLUE.g, FLOOR_LIGHT_BLUE.b))
	floor_material.set_shader_parameter("tile_color_dark", Vector3(FLOOR_DARK_BLUE.r, FLOOR_DARK_BLUE.g, FLOOR_DARK_BLUE.b))
	floor_material.set_shader_parameter("grout_color", Vector3(GROUT_COLOR.r, GROUT_COLOR.g, GROUT_COLOR.b))
	floor_material.set_shader_parameter("tile_size", tile_size)
	floor_material.set_shader_parameter("grout_width", 0.03)
	floor_material.set_shader_parameter("cartoon_style", true)
	
	# Find and update the ground mesh
	var ground = get_node_or_null("../NavigationRegion3D/Ground/MeshInstance3D")
	if ground and ground is MeshInstance3D:
		ground.material_override = floor_material
		print("Kitchen floor material applied!")
	else:
		push_warning("Could not find ground mesh to apply kitchen floor material")

func _create_walls() -> void:
	var walls_container = Node3D.new()
	walls_container.name = "Walls"
	add_child(walls_container)
	
	# Create walls on two sides (like the reference - back and left side visible)
	_create_wall_section(walls_container, Vector3(0, wall_height / 2, -floor_size.y / 2), 
						 Vector3(floor_size.x, wall_height, 0.5), WALL_YELLOW, "BackWall")
	_create_wall_section(walls_container, Vector3(-floor_size.x / 2, wall_height / 2, 0), 
						 Vector3(0.5, wall_height, floor_size.y), WALL_PINK, "LeftWall")

func _create_wall_section(parent: Node3D, pos: Vector3, size: Vector3, color: Color, wall_name: String) -> void:
	var wall = MeshInstance3D.new()
	wall.name = wall_name
	
	var box = BoxMesh.new()
	box.size = size
	wall.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9  # Matte cartoon look
	wall.material_override = mat
	
	wall.position = pos
	parent.add_child(wall)

func _create_counters() -> void:
	var counters_container = Node3D.new()
	counters_container.name = "Counters"
	add_child(counters_container)
	
	# Counter along the right wall (runs along Z axis)
	_create_counter_unit(counters_container, 
						 Vector3(floor_size.x / 2 - counter_depth / 2 - 0.5, 0, -floor_size.y / 4),
						 Vector3(counter_depth, counter_height, floor_size.y * 0.5),
						 "RightCounter",
						 Vector3(0, 0, -1))  # Backsplash faces left (-X)
	
	# Corner counter connecting right wall to back wall
	_create_counter_unit(counters_container,
						 Vector3(floor_size.x / 2 - counter_depth / 2 - 0.5, 0, -floor_size.y / 2 + counter_depth / 2 + 0.5),
						 Vector3(counter_depth, counter_height, counter_depth),
						 "CornerCounter",
						 Vector3(0, 0, 0))  # No backsplash for corner

func _create_counter_unit(parent: Node3D, pos: Vector3, size: Vector3, counter_name: String, backsplash_dir: Vector3 = Vector3(0, 0, -1)) -> void:
	var counter = Node3D.new()
	counter.name = counter_name
	counter.position = pos
	parent.add_child(counter)
	
	# Store bounds for grid registration (add padding for safety)
	var padding = 0.5
	var bound_min = Vector3(
		pos.x - size.x / 2.0 - padding,
		0,
		pos.z - size.z / 2.0 - padding
	)
	var bound_max = Vector3(
		pos.x + size.x / 2.0 + padding,
		0,
		pos.z + size.z / 2.0 + padding
	)
	counter_bounds.append({"min": bound_min, "max": bound_max})
	
	# Cabinet base (yellow)
	var cabinet = MeshInstance3D.new()
	cabinet.name = "Cabinet"
	var cabinet_mesh = BoxMesh.new()
	cabinet_mesh.size = Vector3(size.x, size.y * 0.85, size.z)
	cabinet.mesh = cabinet_mesh
	cabinet.position.y = size.y * 0.85 / 2
	
	var cabinet_mat = StandardMaterial3D.new()
	cabinet_mat.albedo_color = CABINET_YELLOW
	cabinet_mat.roughness = 0.7
	cabinet.material_override = cabinet_mat
	counter.add_child(cabinet)
	
	# Countertop (slightly darker, slight overhang)
	var countertop = MeshInstance3D.new()
	countertop.name = "Countertop"
	var top_mesh = BoxMesh.new()
	top_mesh.size = Vector3(size.x + 0.2, 0.15, size.z + 0.2)
	countertop.mesh = top_mesh
	countertop.position.y = size.y * 0.85 + 0.075
	
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = CABINET_YELLOW_DARK
	top_mat.roughness = 0.5
	countertop.material_override = top_mat
	counter.add_child(countertop)
	
	# Backsplash tiles (blue tiles like reference) - only if direction specified
	if backsplash_dir != Vector3.ZERO:
		_create_backsplash(counter, size, backsplash_dir)

func _create_backsplash(counter: Node3D, counter_size: Vector3, direction: Vector3) -> void:
	var backsplash = MeshInstance3D.new()
	backsplash.name = "Backsplash"
	
	var splash_mesh = BoxMesh.new()
	var splash_height = 3.0
	
	# Determine backsplash orientation based on direction
	# direction.z = -1 means backsplash on -Z side (facing +Z), runs along X
	# direction.x = -1 means backsplash on -X side (facing +X), runs along Z
	if abs(direction.z) > abs(direction.x):
		# Backsplash runs along X axis
		splash_mesh.size = Vector3(counter_size.x, splash_height, 0.2)
		backsplash.position = Vector3(0, counter_size.y * 0.85 + splash_height / 2, -counter_size.z / 2 - 0.1)
	else:
		# Backsplash runs along Z axis
		splash_mesh.size = Vector3(0.2, splash_height, counter_size.z)
		backsplash.position = Vector3(-counter_size.x / 2 - 0.1, counter_size.y * 0.85 + splash_height / 2, 0)
	
	backsplash.mesh = splash_mesh
	
	# Use a simple blue tile material (could enhance with shader later)
	var splash_mat = StandardMaterial3D.new()
	splash_mat.albedo_color = BACKSPLASH_BLUE
	splash_mat.roughness = 0.6
	backsplash.material_override = splash_mat
	
	counter.add_child(backsplash)

func _create_decorative_elements() -> void:
	var decor_container = Node3D.new()
	decor_container.name = "Decorations"
	add_child(decor_container)
	
	# Clock on the wall (like reference)
	_create_wall_clock(decor_container, Vector3(-5, wall_height - 2, -floor_size.y / 2 + 0.3))
	
	# Simple door frame suggestion on left wall
	_create_door_frame(decor_container, Vector3(-floor_size.x / 2 + 0.3, 0, 5))
	
	# Kitchen appliances
	var appliances_container = Node3D.new()
	appliances_container.name = "Appliances"
	add_child(appliances_container)
	
	# Fridge against the back wall (left side)
	_create_fridge(appliances_container, Vector3(-floor_size.x / 2 + 3.5, 0, -floor_size.y / 2 + 2.5))
	
	# Stove along the back wall
	_create_stove(appliances_container, Vector3(5, 0, -floor_size.y / 2 + 2.5))
	
	# Teapot on the right counter
	var teapot_pos = Vector3(floor_size.x / 2 - counter_depth / 2 - 0.5, counter_height + 0.1, -floor_size.y / 4 + 2)
	_create_teapot(appliances_container, teapot_pos)

func _create_wall_clock(parent: Node3D, pos: Vector3) -> void:
	var clock = Node3D.new()
	clock.name = "WallClock"
	clock.position = pos
	parent.add_child(clock)
	
	# Octagonal clock face (simplified as cylinder for now)
	var face = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 0.15
	cyl.radial_segments = 8  # Octagonal
	face.mesh = cyl
	face.rotation.x = deg_to_rad(90)
	
	var face_mat = StandardMaterial3D.new()
	face_mat.albedo_color = BACKSPLASH_BLUE
	face_mat.roughness = 0.8
	face.material_override = face_mat
	
	clock.add_child(face)

func _create_door_frame(parent: Node3D, pos: Vector3) -> void:
	var door = Node3D.new()
	door.name = "DoorFrame"
	door.position = pos
	parent.add_child(door)
	
	var door_width = 4.0
	var door_height = 6.0
	var frame_thickness = 0.3
	
	# Door opening (darker area)
	var opening = MeshInstance3D.new()
	var open_mesh = BoxMesh.new()
	open_mesh.size = Vector3(0.1, door_height, door_width)
	opening.mesh = open_mesh
	opening.position.y = door_height / 2
	
	var open_mat = StandardMaterial3D.new()
	open_mat.albedo_color = Color(0.2, 0.15, 0.1)  # Dark doorway
	opening.material_override = open_mat
	door.add_child(opening)
	
	# Yellow door frame
	_create_frame_piece(door, Vector3(0.15, door_height / 2, door_width / 2 + frame_thickness / 2),
					   Vector3(0.3, door_height, frame_thickness))
	_create_frame_piece(door, Vector3(0.15, door_height / 2, -door_width / 2 - frame_thickness / 2),
					   Vector3(0.3, door_height, frame_thickness))
	_create_frame_piece(door, Vector3(0.15, door_height + frame_thickness / 2, 0),
					   Vector3(0.3, frame_thickness, door_width + frame_thickness * 2))

func _create_frame_piece(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var piece = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.position = pos
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = CABINET_YELLOW
	mat.roughness = 0.7
	piece.material_override = mat
	
	parent.add_child(piece)

func _register_unbuildable_areas() -> void:
	# Find the MapGrid node
	map_grid = get_node_or_null("../MapGrid")
	if not map_grid:
		push_warning("KitchenEnvironment: Could not find MapGrid to register unbuildable areas")
		return
	
	print("Registering ", counter_bounds.size(), " counter areas as unbuildable")
	
	for bounds in counter_bounds:
		map_grid.mark_area_unbuildable(bounds["min"], bounds["max"])
	
	print("Kitchen obstacles registered with grid")

## Creates a cartoon-style refrigerator with doors open (enemies are raiding it!)
func _create_fridge(parent: Node3D, pos: Vector3) -> void:
	var fridge = Node3D.new()
	fridge.name = "Fridge"
	fridge.position = pos
	parent.add_child(fridge)
	
	var fridge_width = 3.5
	var fridge_depth = 2.5
	var fridge_height = 6.0
	var door_thickness = 0.15
	
	# Main body
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(fridge_width, fridge_height, fridge_depth)
	body.mesh = body_mesh
	body.position.y = fridge_height / 2
	
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = FRIDGE_WHITE
	body_mat.roughness = 0.3
	body_mat.metallic = 0.1
	body.material_override = body_mat
	fridge.add_child(body)
	
	# Interior (darker to show depth)
	var interior = MeshInstance3D.new()
	var interior_mesh = BoxMesh.new()
	interior_mesh.size = Vector3(fridge_width - 0.2, fridge_height - 0.2, fridge_depth - 0.3)
	interior.mesh = interior_mesh
	interior.position = Vector3(0, fridge_height / 2, 0.1)
	
	var interior_mat = StandardMaterial3D.new()
	interior_mat.albedo_color = Color(0.85, 0.88, 0.9)  # Slightly blue-white interior
	interior_mat.roughness = 0.5
	interior.material_override = interior_mat
	fridge.add_child(interior)
	
	# Shelves inside
	var shelf_mat = StandardMaterial3D.new()
	shelf_mat.albedo_color = Color(0.8, 0.82, 0.85)
	shelf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shelf_mat.albedo_color.a = 0.7
	
	for shelf_y in [1.5, 2.5, 3.5, 4.8]:
		var shelf = MeshInstance3D.new()
		var shelf_mesh = BoxMesh.new()
		shelf_mesh.size = Vector3(fridge_width - 0.4, 0.08, fridge_depth - 0.5)
		shelf.mesh = shelf_mesh
		shelf.position = Vector3(0, shelf_y, 0.1)
		shelf.material_override = shelf_mat
		fridge.add_child(shelf)
	
	# Food items inside the fridge!
	_create_fridge_food(fridge, fridge_width, fridge_depth)
	
	# Freezer door (top) - swung open into the room
	# Pivot on right edge, positive Y rotation swings door toward +Z (into room)
	var freezer_door_pivot = Node3D.new()
	freezer_door_pivot.name = "FreezerDoorPivot"
	freezer_door_pivot.position = Vector3(fridge_width / 2, fridge_height * 0.82, fridge_depth / 2)
	freezer_door_pivot.rotation.y = deg_to_rad(100)  # Positive = swings into room
	fridge.add_child(freezer_door_pivot)
	
	var freezer_door = MeshInstance3D.new()
	var freezer_mesh = BoxMesh.new()
	freezer_mesh.size = Vector3(fridge_width - 0.1, fridge_height * 0.3, door_thickness)
	freezer_door.mesh = freezer_mesh
	freezer_door.position = Vector3(-fridge_width / 2 + 0.05, 0, door_thickness / 2)
	
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = FRIDGE_SILVER
	door_mat.roughness = 0.2
	door_mat.metallic = 0.3
	freezer_door.material_override = door_mat
	freezer_door_pivot.add_child(freezer_door)
	
	# Handle on freezer door
	_create_fridge_handle(freezer_door, Vector3(-fridge_width / 2 + 0.6, 0, door_thickness / 2 + 0.05))
	
	# Main door (bottom) - swung open into the room
	# Pivot on left edge, negative Y rotation swings door toward +Z (into room)
	var main_door_pivot = Node3D.new()
	main_door_pivot.name = "MainDoorPivot"
	main_door_pivot.position = Vector3(-fridge_width / 2, fridge_height * 0.35, fridge_depth / 2)
	main_door_pivot.rotation.y = deg_to_rad(-100)  # Negative = swings into room
	fridge.add_child(main_door_pivot)
	
	var main_door = MeshInstance3D.new()
	var main_mesh = BoxMesh.new()
	main_mesh.size = Vector3(fridge_width - 0.1, fridge_height * 0.55, door_thickness)
	main_door.mesh = main_mesh
	main_door.position = Vector3(fridge_width / 2 - 0.05, 0, door_thickness / 2)
	main_door.material_override = door_mat
	main_door_pivot.add_child(main_door)
	
	# Door shelves on main door
	var door_shelf_mat = StandardMaterial3D.new()
	door_shelf_mat.albedo_color = Color(0.9, 0.9, 0.92)
	door_shelf_mat.roughness = 0.4
	
	for shelf_y in [-0.8, -0.2, 0.4]:
		var door_shelf = MeshInstance3D.new()
		var ds_mesh = BoxMesh.new()
		ds_mesh.size = Vector3(fridge_width - 0.5, 0.3, 0.4)
		door_shelf.mesh = ds_mesh
		door_shelf.position = Vector3(fridge_width / 2 - 0.3, shelf_y, door_thickness / 2 + 0.25)
		door_shelf.material_override = door_shelf_mat
		main_door_pivot.add_child(door_shelf)
	
	# Handle on main door
	_create_fridge_handle(main_door, Vector3(fridge_width / 2 - 0.6, 0.3, door_thickness / 2 + 0.05))
	
	# Light glow effect from inside (optional visual flair)
	var fridge_light = OmniLight3D.new()
	fridge_light.light_color = Color(0.95, 0.98, 1.0)
	fridge_light.light_energy = 0.5
	fridge_light.omni_range = 4.0
	fridge_light.position = Vector3(0, fridge_height / 2, fridge_depth / 2 + 0.5)
	fridge.add_child(fridge_light)
	
	# Register as unbuildable (larger area due to open doors)
	var padding = 2.0  # Extra space for open doors
	counter_bounds.append({
		"min": Vector3(pos.x - fridge_width / 2 - padding, 0, pos.z - fridge_depth / 2 - padding),
		"max": Vector3(pos.x + fridge_width / 2 + padding, 0, pos.z + fridge_depth / 2 + padding)
	})

## Creates food items inside the open fridge
func _create_fridge_food(fridge: Node3D, fridge_width: float, fridge_depth: float) -> void:
	# Milk carton
	var milk = MeshInstance3D.new()
	var milk_mesh = BoxMesh.new()
	milk_mesh.size = Vector3(0.3, 0.6, 0.3)
	milk.mesh = milk_mesh
	milk.position = Vector3(-0.5, 1.8, 0.3)
	
	var milk_mat = StandardMaterial3D.new()
	milk_mat.albedo_color = Color(0.95, 0.95, 0.98)
	milk.material_override = milk_mat
	fridge.add_child(milk)
	
	# Red juice/sauce bottle
	var bottle = MeshInstance3D.new()
	var bottle_mesh = CylinderMesh.new()
	bottle_mesh.top_radius = 0.1
	bottle_mesh.bottom_radius = 0.15
	bottle_mesh.height = 0.5
	bottle.mesh = bottle_mesh
	bottle.position = Vector3(0.6, 1.75, 0.2)
	
	var bottle_mat = StandardMaterial3D.new()
	bottle_mat.albedo_color = Color(0.8, 0.2, 0.2)
	bottle.material_override = bottle_mat
	fridge.add_child(bottle)
	
	# Cheese wedge
	var cheese = MeshInstance3D.new()
	var cheese_mesh = PrismMesh.new()
	cheese_mesh.size = Vector3(0.4, 0.25, 0.5)
	cheese.mesh = cheese_mesh
	cheese.position = Vector3(0.2, 2.65, 0.1)
	cheese.rotation.y = deg_to_rad(30)
	
	var cheese_mat = StandardMaterial3D.new()
	cheese_mat.albedo_color = Color(1.0, 0.85, 0.3)  # Yellow cheese
	cheese.material_override = cheese_mat
	fridge.add_child(cheese)
	
	# Apple (red sphere)
	var apple = MeshInstance3D.new()
	var apple_mesh = SphereMesh.new()
	apple_mesh.radius = 0.15
	apple_mesh.height = 0.3
	apple.mesh = apple_mesh
	apple.position = Vector3(-0.6, 2.65, 0.3)
	
	var apple_mat = StandardMaterial3D.new()
	apple_mat.albedo_color = Color(0.8, 0.15, 0.15)
	apple.material_override = apple_mat
	fridge.add_child(apple)
	
	# Orange
	var orange = MeshInstance3D.new()
	var orange_mesh = SphereMesh.new()
	orange_mesh.radius = 0.14
	orange_mesh.height = 0.28
	orange.mesh = orange_mesh
	orange.position = Vector3(-0.3, 2.65, 0.4)
	
	var orange_mat = StandardMaterial3D.new()
	orange_mat.albedo_color = Color(1.0, 0.6, 0.1)
	orange.material_override = orange_mat
	fridge.add_child(orange)
	
	# Cake! (the main prize - what enemies really want)
	var cake = Node3D.new()
	cake.name = "DeliciousCake"
	cake.position = Vector3(0, 3.65, 0.2)
	fridge.add_child(cake)
	
	# Cake base
	var cake_base = MeshInstance3D.new()
	var cake_mesh = CylinderMesh.new()
	cake_mesh.top_radius = 0.4
	cake_mesh.bottom_radius = 0.45
	cake_mesh.height = 0.35
	cake_base.mesh = cake_mesh
	
	var cake_mat = StandardMaterial3D.new()
	cake_mat.albedo_color = Color(0.95, 0.85, 0.7)  # Vanilla/sponge color
	cake_base.material_override = cake_mat
	cake.add_child(cake_base)
	
	# Frosting top
	var frosting = MeshInstance3D.new()
	var frost_mesh = CylinderMesh.new()
	frost_mesh.top_radius = 0.42
	frost_mesh.bottom_radius = 0.42
	frost_mesh.height = 0.08
	frosting.mesh = frost_mesh
	frosting.position.y = 0.2
	
	var frost_mat = StandardMaterial3D.new()
	frost_mat.albedo_color = Color(1.0, 0.7, 0.75)  # Pink frosting
	frosting.material_override = frost_mat
	cake.add_child(frosting)
	
	# Cherry on top!
	var cherry = MeshInstance3D.new()
	var cherry_mesh = SphereMesh.new()
	cherry_mesh.radius = 0.08
	cherry_mesh.height = 0.16
	cherry.mesh = cherry_mesh
	cherry.position.y = 0.32
	
	var cherry_mat = StandardMaterial3D.new()
	cherry_mat.albedo_color = Color(0.7, 0.05, 0.1)
	cherry.material_override = cherry_mat
	cake.add_child(cherry)
	
	# Leftover/spilled items on the floor (enemies have been here!)
	# Knocked over bottle
	var spilled_bottle = MeshInstance3D.new()
	spilled_bottle.mesh = bottle_mesh
	spilled_bottle.position = Vector3(0.8, 0.15, fridge_depth / 2 + 1.0)
	spilled_bottle.rotation.z = deg_to_rad(90)
	
	var spilled_mat = StandardMaterial3D.new()
	spilled_mat.albedo_color = Color(0.2, 0.6, 0.3)  # Green bottle
	spilled_bottle.material_override = spilled_mat
	fridge.add_child(spilled_bottle)
	
	# Dropped apple
	var dropped_apple = MeshInstance3D.new()
	dropped_apple.mesh = apple_mesh
	dropped_apple.position = Vector3(-1.2, 0.15, fridge_depth / 2 + 1.5)
	dropped_apple.material_override = apple_mat
	fridge.add_child(dropped_apple)

func _create_fridge_handle(parent: Node3D, pos: Vector3) -> void:
	var handle = MeshInstance3D.new()
	var handle_mesh = BoxMesh.new()
	handle_mesh.size = Vector3(0.15, 0.8, 0.1)
	handle.mesh = handle_mesh
	handle.position = pos
	
	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = FRIDGE_SILVER
	handle_mat.roughness = 0.1
	handle_mat.metallic = 0.5
	handle.material_override = handle_mat
	parent.add_child(handle)

## Creates a cartoon-style stove/oven
func _create_stove(parent: Node3D, pos: Vector3) -> void:
	var stove = Node3D.new()
	stove.name = "Stove"
	stove.position = pos
	parent.add_child(stove)
	
	var stove_width = 3.5
	var stove_depth = 2.5
	var stove_height = 3.0
	
	# Main body (oven part)
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(stove_width, stove_height, stove_depth)
	body.mesh = body_mesh
	body.position.y = stove_height / 2
	
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = STOVE_WHITE
	body_mat.roughness = 0.4
	body.material_override = body_mat
	stove.add_child(body)
	
	# Oven door (black glass)
	var oven_door = MeshInstance3D.new()
	var door_mesh = BoxMesh.new()
	door_mesh.size = Vector3(stove_width * 0.8, stove_height * 0.5, 0.1)
	oven_door.mesh = door_mesh
	oven_door.position = Vector3(0, stove_height * 0.35, stove_depth / 2 + 0.05)
	
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = STOVE_BLACK
	door_mat.roughness = 0.1
	door_mat.metallic = 0.2
	oven_door.material_override = door_mat
	stove.add_child(oven_door)
	
	# Stovetop surface
	var stovetop = MeshInstance3D.new()
	var top_mesh = BoxMesh.new()
	top_mesh.size = Vector3(stove_width + 0.1, 0.1, stove_depth + 0.1)
	stovetop.mesh = top_mesh
	stovetop.position.y = stove_height + 0.05
	
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = STOVE_BLACK
	top_mat.roughness = 0.2
	stovetop.material_override = top_mat
	stove.add_child(stovetop)
	
	# Burners (4 burners in a grid)
	var burner_positions = [
		Vector3(-0.7, stove_height + 0.12, -0.5),
		Vector3(0.7, stove_height + 0.12, -0.5),
		Vector3(-0.7, stove_height + 0.12, 0.5),
		Vector3(0.7, stove_height + 0.12, 0.5)
	]
	
	for burner_pos in burner_positions:
		_create_burner(stove, burner_pos)
	
	# Control knobs
	for i in range(4):
		var knob_x = -stove_width / 2 + 0.5 + i * 0.8
		_create_stove_knob(stove, Vector3(knob_x, stove_height * 0.85, stove_depth / 2 + 0.1))
	
	# Backsplash behind stove
	var backsplash = MeshInstance3D.new()
	var splash_mesh = BoxMesh.new()
	splash_mesh.size = Vector3(stove_width + 0.5, 3.0, 0.2)
	backsplash.mesh = splash_mesh
	backsplash.position = Vector3(0, stove_height + 1.5, -stove_depth / 2 - 0.1)
	
	var splash_mat = StandardMaterial3D.new()
	splash_mat.albedo_color = BACKSPLASH_BLUE
	splash_mat.roughness = 0.6
	backsplash.material_override = splash_mat
	stove.add_child(backsplash)
	
	# Register as unbuildable
	var padding = 0.5
	counter_bounds.append({
		"min": Vector3(pos.x - stove_width / 2 - padding, 0, pos.z - stove_depth / 2 - padding),
		"max": Vector3(pos.x + stove_width / 2 + padding, 0, pos.z + stove_depth / 2 + padding)
	})

func _create_burner(parent: Node3D, pos: Vector3) -> void:
	var burner = MeshInstance3D.new()
	var burner_mesh = CylinderMesh.new()
	burner_mesh.top_radius = 0.4
	burner_mesh.bottom_radius = 0.4
	burner_mesh.height = 0.05
	burner_mesh.radial_segments = 16
	burner.mesh = burner_mesh
	burner.position = pos
	
	var burner_mat = StandardMaterial3D.new()
	burner_mat.albedo_color = Color(0.25, 0.25, 0.25)
	burner_mat.roughness = 0.3
	burner.material_override = burner_mat
	parent.add_child(burner)

func _create_stove_knob(parent: Node3D, pos: Vector3) -> void:
	var knob = MeshInstance3D.new()
	var knob_mesh = CylinderMesh.new()
	knob_mesh.top_radius = 0.12
	knob_mesh.bottom_radius = 0.12
	knob_mesh.height = 0.15
	knob_mesh.radial_segments = 12
	knob.mesh = knob_mesh
	knob.position = pos
	knob.rotation.x = deg_to_rad(90)
	
	var knob_mat = StandardMaterial3D.new()
	knob_mat.albedo_color = STOVE_BLACK
	knob_mat.roughness = 0.3
	knob.material_override = knob_mat
	parent.add_child(knob)

## Creates a cartoon-style teapot (like the reference image)
func _create_teapot(parent: Node3D, pos: Vector3) -> void:
	var teapot = Node3D.new()
	teapot.name = "Teapot"
	teapot.position = pos
	parent.add_child(teapot)
	
	# Main body (rounded using a sphere-ish shape)
	var body = MeshInstance3D.new()
	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.5
	body_mesh.height = 0.8
	body_mesh.radial_segments = 16
	body_mesh.rings = 8
	body.mesh = body_mesh
	body.position.y = 0.4
	
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = TEAPOT_BLUE
	body_mat.roughness = 0.4
	body_mat.metallic = 0.1
	body.material_override = body_mat
	teapot.add_child(body)
	
	# Lid
	var lid = MeshInstance3D.new()
	var lid_mesh = CylinderMesh.new()
	lid_mesh.top_radius = 0.15
	lid_mesh.bottom_radius = 0.25
	lid_mesh.height = 0.15
	lid.mesh = lid_mesh
	lid.position.y = 0.85
	lid.material_override = body_mat
	teapot.add_child(lid)
	
	# Lid knob
	var lid_knob = MeshInstance3D.new()
	var knob_mesh = SphereMesh.new()
	knob_mesh.radius = 0.08
	knob_mesh.height = 0.16
	lid_knob.mesh = knob_mesh
	lid_knob.position.y = 0.98
	lid_knob.material_override = body_mat
	teapot.add_child(lid_knob)
	
	# Spout
	var spout = MeshInstance3D.new()
	var spout_mesh = CylinderMesh.new()
	spout_mesh.top_radius = 0.08
	spout_mesh.bottom_radius = 0.12
	spout_mesh.height = 0.4
	spout.mesh = spout_mesh
	spout.position = Vector3(0.45, 0.5, 0)
	spout.rotation.z = deg_to_rad(-45)
	spout.material_override = body_mat
	teapot.add_child(spout)
	
	# Handle
	var handle = MeshInstance3D.new()
	var handle_mesh = TorusMesh.new()
	handle_mesh.inner_radius = 0.12
	handle_mesh.outer_radius = 0.22
	handle_mesh.rings = 12
	handle_mesh.ring_segments = 8
	handle.mesh = handle_mesh
	handle.position = Vector3(-0.45, 0.45, 0)
	handle.rotation.y = deg_to_rad(90)
	handle.material_override = body_mat
	teapot.add_child(handle)
	
	# Decorative flower/pattern dots (like the reference)
	var dot_positions = [
		Vector3(0.35, 0.45, 0.3),
		Vector3(0.2, 0.55, 0.4),
		Vector3(0.0, 0.5, 0.48),
		Vector3(-0.15, 0.4, 0.45),
	]
	
	var dot_mat = StandardMaterial3D.new()
	dot_mat.albedo_color = TEAPOT_PATTERN
	dot_mat.roughness = 0.5
	
	for dot_pos in dot_positions:
		var dot = MeshInstance3D.new()
		var dot_mesh = SphereMesh.new()
		dot_mesh.radius = 0.05
		dot_mesh.height = 0.1
		dot.mesh = dot_mesh
		dot.position = dot_pos
		dot.material_override = dot_mat
		teapot.add_child(dot)

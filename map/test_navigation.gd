extends Node3D

func _ready():
	# Find and bake navigation
	var nav_region = find_navigation_region(get_tree().root)
	if nav_region:
		print("Found NavigationRegion3D, baking...")
		nav_region.bake_navigation_mesh()
		
		# Wait for bake
		await get_tree().process_frame
		await get_tree().process_frame
		
		if nav_region.navigation_mesh:
			var vertices = nav_region.navigation_mesh.get_vertices()
			var polygon_count = nav_region.navigation_mesh.get_polygon_count()
			
			print("Navmesh bake results:")
			print("  Vertices: ", vertices.size())
			print("  Polygons: ", polygon_count)
			
			if vertices.size() > 0:
				print("  ✓ Navmesh HAS geometry - bake successful!")
				print("  Sample vertex positions:")
				for i in min(5, vertices.size()):
					print("    ", vertices[i])
			else:
				print("  ✗ Navmesh is EMPTY - bake failed!")
	
	# Small delay
	await get_tree().create_timer(0.5).timeout
	
	print("=== Navigation Test Starting ===")
	
	# Check if navigation exists
	var nav_map = get_world_3d().get_navigation_map()
	print("Navigation map ID: ", nav_map)
	
	# Find NavigationRegion3D
	if nav_region:
		print("✓ Found NavigationRegion3D: ", nav_region.name)
		
		if nav_region.navigation_mesh:
			print("✓ NavigationMesh exists")
			print("  - Agent radius: ", nav_region.navigation_mesh.agent_radius)
			print("  - Agent height: ", nav_region.navigation_mesh.agent_height)
			print("  - Parsed Geometry Type: ", nav_region.navigation_mesh.geometry_parsed_geometry_type)
			print("  - Source Geometry Mode: ", nav_region.navigation_mesh.geometry_source_geometry_mode)
		else:
			print("✗ ERROR: No NavigationMesh assigned!")
			return
	else:
		print("✗ ERROR: No NavigationRegion3D found in scene!")
		return
	
	# Find ground
	var ground = find_ground(get_tree().root)
	if ground:
		print("✓ Found ground: ", ground.name, " (Type: ", ground.get_class(), ")")
		
		# Check for collision
		var has_collision = false
		for child in ground.get_children():
			if child is CollisionShape3D:
				has_collision = true
				print("  ✓ Has collision shape: ", child.shape.get_class() if child.shape else "No shape!")
				break
		
		if not has_collision:
			print("  ✗ ERROR: Ground has no CollisionShape3D!")
			return
	else:
		print("✗ WARNING: No ground node found")
		return
	
	# Test pathfinding with adaptive positions
	test_navigation_adaptive(ground)

func test_navigation_adaptive(ground: Node):
	# Find collision shape to get ground size
	var collision_shape: CollisionShape3D = null
	for child in ground.get_children():
		if child is CollisionShape3D:
			collision_shape = child
			break
	
	if collision_shape and collision_shape.shape is BoxShape3D:
		var box_shape = collision_shape.shape as BoxShape3D
		var ground_pos = ground.global_position + collision_shape.position
		var half_size = box_shape.size / 2.0
		
		print("\nGround Info:")
		print("  Position: ", ground_pos)
		print("  Size: ", box_shape.size)
		
		# Test paths within ground bounds
		var y_offset = ground_pos.y + half_size.y + 0.5
		var test_distance = min(half_size.x, half_size.z) * 0.4  # Stay well within bounds
		
		print("\n=== Testing Pathfinding ===")
		print("Test distance: ", test_distance)
		print("Y offset: ", y_offset)
		
		test_path(
			Vector3(ground_pos.x - test_distance, y_offset, ground_pos.z),
			Vector3(ground_pos.x + test_distance, y_offset, ground_pos.z),
			"Horizontal"
		)
		test_path(
			Vector3(ground_pos.x, y_offset, ground_pos.z - test_distance),
			Vector3(ground_pos.x, y_offset, ground_pos.z + test_distance),
			"Vertical"
		)
		test_path(
			Vector3(ground_pos.x - test_distance, y_offset, ground_pos.z - test_distance),
			Vector3(ground_pos.x + test_distance, y_offset, ground_pos.z + test_distance),
			"Diagonal"
		)
	else:
		print("Can't determine ground size, using default positions")
		test_path(Vector3(-10, 0.5, 0), Vector3(10, 0.5, 0), "Horizontal")

func test_path(start: Vector3, end: Vector3, label: String):
	print("\n%s: from %v to %v" % [label, start, end])
	
	var path = NavigationServer3D.map_get_path(
		get_world_3d().get_navigation_map(),
		start,
		end,
		true
	)
	
	print("  Result: %d points" % path.size())
	
	if path.size() > 0:
		print("  ✓ Path found!")
		visualize_path(path, label)
	else:
		print("  ✗ No path found")

func visualize_path(path: PackedVector3Array, label: String):
	for i in path.size():
		var sphere = MeshInstance3D.new()
		sphere.name = "PathPoint_%s_%d" % [label, i]
		
		var mesh = SphereMesh.new()
		mesh.radius = 0.3
		sphere.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		if i == 0:
			mat.albedo_color = Color.RED
		elif i == path.size() - 1:
			mat.albedo_color = Color.GREEN
		else:
			mat.albedo_color = Color.YELLOW
		
		sphere.material_override = mat
		sphere.position = path[i]
		add_child(sphere)

func find_navigation_region(node: Node) -> NavigationRegion3D:
	if node is NavigationRegion3D:
		return node
	
	for child in node.get_children():
		var result = find_navigation_region(child)
		if result:
			return result
	
	return null

func find_ground(node: Node) -> Node:
	if node.name.to_lower().contains("ground"):
		return node
	
	for child in node.get_children():
		var result = find_ground(child)
		if result:
			return result
	
	return null

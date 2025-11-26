# tower_placer.gd
extends Node3D

@export var tower_scene: PackedScene
@export var map_grid: MapGrid
@export var camera: Camera3D

var preview_tower: Node3D = null

func _input(event):
	if event is InputEventMouseMotion:
		update_preview()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_place_tower()

func update_preview():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
	var result = space_state.intersect_ray(query)
	
	if result:
		var world_pos = result.position
		var grid_pos = map_grid.world_to_grid(world_pos)
		
		if not preview_tower:
			preview_tower = MeshInstance3D.new()
			preview_tower.mesh = BoxMesh.new()
			add_child(preview_tower)
		
		preview_tower.global_position = map_grid.grid_to_world(grid_pos)
		
		# Visual feedback
		if map_grid.is_valid_build_position(grid_pos):
			preview_tower.modulate = Color(0, 1, 0, 0.5)  # Green = valid
		else:
			preview_tower.modulate = Color(1, 0, 0, 0.5)  # Red = invalid

func try_place_tower():
	if not preview_tower:
		return
	
	var grid_pos = map_grid.world_to_grid(preview_tower.global_position)
	
	if map_grid.is_valid_build_position(grid_pos):
		var tower = tower_scene.instantiate()
		tower.global_position = map_grid.grid_to_world(grid_pos)
		get_node("/root/World/Towers").add_child(tower)
		
		map_grid.occupy_cell(grid_pos)

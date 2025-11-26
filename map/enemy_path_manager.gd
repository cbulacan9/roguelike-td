# enemy_path_manager.gd
extends Node3D
class_name EnemyPathManager

@export var navigation_region: NavigationRegion3D
@export var spawn_points: Array[Marker3D] = []
@export var goal_position: Marker3D

func get_random_spawn_point() -> Vector3:
	if spawn_points.is_empty():
		push_error("No spawn points defined!")
		return Vector3.ZERO
	return spawn_points[randi() % spawn_points.size()].global_position

func get_path_to_goal(from_position: Vector3) -> PackedVector3Array:
	if not navigation_region:
		push_error("Navigation region not set!")
		return PackedVector3Array()
	
	var navigation_map = navigation_region.get_navigation_map()
	return NavigationServer3D.map_get_path(
		navigation_map,
		from_position,
		goal_position.global_position,
		true
	)

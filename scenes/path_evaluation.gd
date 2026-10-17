
extends Node
class_name PathEvaluation

# Helper class for selecting eligible portal

# How close a navigation path must pass to a doorway.
const PORTAL_PATH_TOLERANCE: float = 16.0

# Tolerance for checking navigation path endpoints.
const PATH_ENDPOINT_TOLERANCE: float = 12.0

# Find the shortest distance from a point to a path.
func distance_to_path(
	point: Vector2,
	path: PackedVector2Array
) -> float:
	if path.is_empty():
		return INF

	var closest_distance: float = INF

	for i in range(path.size() - 1):
		var closest_point: Vector2 = (
			Geometry2D.get_closest_point_to_segment(
				point,
				path[i],
				path[i + 1]
			)
		)

		closest_distance = minf(
			closest_distance,
			point.distance_to(closest_point)
		)

	return closest_distance


func is_path_usable(
	path: PackedVector2Array,
	target: Vector2
) -> bool:
	if path.size() < 2:
		return false

	# NavigationServer2D can return a partial path.
	# Make sure the final point actually reaches the target.
	if path[path.size() - 1].distance_to(target) > PATH_ENDPOINT_TOLERANCE:
		return false

	return true


func get_path_length(path: PackedVector2Array) -> float:
	var total_length: float = 0.0

	for i in range(path.size() - 1):
		total_length += path[i].distance_to(path[i + 1])

	return total_length

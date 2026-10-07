extends Node
class_name BottleneckAvoidance

@onready var parent: CrowdAgent = get_parent().get_parent()

@export var detection_time: float = 2.0
@export var speed_threshold: float = 5.0
@export var pushing_threshold: int = 2
@export var alternative_distance: float = 72.0
@export var waypoint_reached_distance: float = 12.0

var rerouting: bool = false
var alternative_point: Vector2 = Vector2.ZERO

var bottleneck_timer: float = 0.0
var bottleneck_detected: bool = false


func update(delta: float) -> void:
	
	if rerouting:
		update_alternative_route()
		return

	if not parent.agent_state.is_impatient():
		reset()
		return

	var moving_slowly: bool = (
		parent.velocity.length() < speed_threshold
	)

	var crowded: bool = (
		parent.repulsion.agent_repulsion_forces.size()
		>= pushing_threshold
	)

	var blocked: bool = (
		parent.rules.waiting_rule
		or parent.rules.stopping_rule
		or crowded
	)
	if moving_slowly and blocked:
		bottleneck_timer += delta
	else:
		bottleneck_timer -= delta * 0.25
		bottleneck_timer = max(bottleneck_timer, 0.0)

	if bottleneck_timer >= detection_time:
		if not bottleneck_detected:
			bottleneck_detected = true

			if not rerouting:
				start_alternative_route()
	else:
		bottleneck_detected = false
		
func get_alternative_directions() -> Array[Vector2]:
	var forward := parent.desired_velocity.normalized()

	if forward.length_squared() <= 0.0001:
		return []

	var right := Vector2(-forward.y, forward.x)

	return [
		(forward * 0.5 + right).normalized(),
		(forward * 0.5 - right).normalized()
	]

func find_alternative_point() -> Vector2:
	var directions := get_alternative_directions()

	if directions.is_empty():
		return Vector2.ZERO

	var navigation_map: RID = parent.get_world_2d().navigation_map

	var best_point := Vector2.ZERO
	var best_distance := INF

	for direction in directions:
		var candidate := (
			parent.global_position
			+ direction * alternative_distance
		)

		# Snap candidate onto the actual navmesh.
		var nav_point := NavigationServer2D.map_get_closest_point(
			navigation_map,
			candidate
		)

		# Don't accept it if snapping moved it a huge distance.
		if nav_point.distance_to(candidate) > 12.0:
			continue

		# For now, prefer whichever valid candidate required
		# the least snapping.
		var distance := nav_point.distance_to(candidate)

		if distance < best_distance:
			best_distance = distance
			best_point = nav_point

	return best_point

func start_alternative_route() -> void:
	alternative_point = find_alternative_point()

	if alternative_point == Vector2.ZERO:
		return

	# IMPORTANT:
	# Forces.request_path(), not parent.request_path().
	# This preserves parent.goal as the real final destination.
	if parent.forces.request_path(alternative_point):
		rerouting = true
		print(parent.name, " rerouting through ", alternative_point)

func update_alternative_route() -> void:
	if parent.global_position.distance_to(alternative_point) <= waypoint_reached_distance:
		rerouting = false
		alternative_point = Vector2.ZERO

		# Go back toward the REAL destination.
		parent.forces.request_path(parent.goal)

		reset()

func reset() -> void:
	bottleneck_timer = 0.0
	bottleneck_detected = false

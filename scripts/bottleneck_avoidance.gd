extends Node
class_name BottleneckAvoidance

# TODO: Keep track of congested portals to avoid being rerouted to there again

# HiDAC bottleneck detection and portal-based rerouting.
@onready var parent: CrowdAgent = get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 5.0
const VISIBLE_AGENTS_THRESHOLD: int = 6

# How close a navigation path must pass to a doorway.
const PORTAL_PATH_TOLERANCE: float = 16.0

# Tolerance for checking navigation path endpoints.
const PATH_ENDPOINT_TOLERANCE: float = 12.0

# Congestion detection.
@export var congestion_timer_threshold: float = 2.0
@export var congestion_decay_rate: float = 0.25

var congestion_timer: float = 0.0
var bottleneck_detected: bool = false

# Avoid repeatedly requesting paths when rerouting fails.
@export var retry_cooldown: float = 2.0
var retry_timer: float = 0.0

# Rerouting
var rerouting: bool = false
var alternative_point: Vector2 = Vector2.ZERO

@export var alternative_reached_distance: float = 12.0
@export var rerouting_timeout: float = 5.0
var rerouting_timer: float = 0.0
var previous_distance: float = INF
const MIN_PROGRESS: float = 0.1


func update(delta: float) -> void:
	if not parent.agent_state.is_impatient():
		if rerouting or bottleneck_detected:
			reset()
		return

	retry_timer = maxf(retry_timer - delta, 0.0)

	if rerouting:
		update_rerouting(delta)
		return

	# Accumulate congestion only when movement is obstructed.
	if is_route_congested():
		congestion_timer += delta
	else:
		congestion_timer = maxf(
			congestion_timer - delta * congestion_decay_rate,
			0.0
		)

	if congestion_timer <= 0.0 and bottleneck_detected:
		bottleneck_detected = false
		parent.queue_redraw()

	if congestion_timer < congestion_timer_threshold:
		return

	if retry_timer > 0.0:
		return

	bottleneck_detected = true
	parent.queue_redraw()

	# Avoid retrying every physics frame.
	retry_timer = retry_cooldown

	var candidate: Vector2 = get_best_alternative_point()

	if candidate == Vector2.ZERO:
		print(parent.name, " found no valid alternative portal")
		return

	print(parent.name, " BEST alternative: ", candidate)
	start_rerouting(candidate)


func is_route_congested() -> bool:
	var not_moving: bool = (
		parent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
		or parent.rules.stopping_rule
		or parent.rules.waiting_rule
	)

	var blocked_by_others: bool = (
		parent.forces.visible_agents.size()
		>= VISIBLE_AGENTS_THRESHOLD
	)

	return not_moving and blocked_by_others


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


# Identify the portal on the agent's intended route,
# rather than assuming the nearest portal is congested.
func get_congested_portal(
	open_portals: Array[Vector2]
) -> Vector2:
	var navigation_map: RID = parent.get_world_2d().navigation_map

	var current_path: PackedVector2Array = (
		NavigationServer2D.map_get_path(
			navigation_map,
			parent.global_position,
			parent.goal,
			true
		)
	)

	if not is_path_usable(current_path, parent.goal):
		return Vector2.ZERO

	var congested_portal: Vector2 = Vector2.ZERO
	var closest_distance: float = INF

	for portal_pos in open_portals:
		var distance: float = distance_to_path(
			portal_pos,
			current_path
		)

		if distance < closest_distance:
			closest_distance = distance
			congested_portal = portal_pos

	# Congestion not associated with a portal on this route.
	if closest_distance > PORTAL_PATH_TOLERANCE:
		return Vector2.ZERO

	return congested_portal


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


func get_best_alternative_point() -> Vector2:
	var level = parent.crowd_manager.lvl

	var open_portals: Array[Vector2] = (
		level.get_open_portal_positions()
	)

	if open_portals.size() < 2:
		return Vector2.ZERO

	var congested_portal: Vector2 = get_congested_portal(
		open_portals
	)

	if congested_portal == Vector2.ZERO:
		print(parent.name, " no congested portal found on route")
		return Vector2.ZERO

	print(parent.name, " congested portal: ", congested_portal)

	var navigation_map: RID = parent.get_world_2d().navigation_map

	var shortest_length: float = INF
	var best_point: Vector2 = Vector2.ZERO

	for portal_pos in open_portals:
		# Never choose the congested doorway itself.
		if portal_pos == congested_portal:
			continue

		# Current position -> alternative portal.
		var path_to_portal: PackedVector2Array = (
			NavigationServer2D.map_get_path(
				navigation_map,
				parent.global_position,
				portal_pos,
				true
			)
		)

		if not is_path_usable(path_to_portal, portal_pos):
			continue

		# Alternative portal -> original goal.
		var path_to_goal: PackedVector2Array = (
			NavigationServer2D.map_get_path(
				navigation_map,
				portal_pos,
				parent.goal,
				true
			)
		)

		if not is_path_usable(path_to_goal, parent.goal):
			continue

		# Reject alternatives that still require passing
		# through the congested doorway.
		if (
			distance_to_path(congested_portal, path_to_portal)
			<= PORTAL_PATH_TOLERANCE
		):
			continue

		if (
			distance_to_path(congested_portal, path_to_goal)
			<= PORTAL_PATH_TOLERANCE
		):
			continue

		var total_length: float = (
			get_path_length(path_to_portal)
			+ get_path_length(path_to_goal)
		)

		print(
			parent.name,
			" portal: ", portal_pos,
			" | route length: ", total_length
		)

		if total_length < shortest_length:
			shortest_length = total_length
			best_point = portal_pos

	return best_point


func start_rerouting(candidate: Vector2) -> void:
	var success: bool = parent.forces.request_path(candidate)
	

	if not success:
		# request_path() sets the navigation target even
		# when its reachability check returns false.
		# Restore the original destination.
		parent.forces.request_path(parent.goal)

		print(parent.name, " failed to reroute to ", candidate)
		return

	alternative_point = candidate
	rerouting = true
	rerouting_timer = 0.0
	previous_distance = parent.global_position.distance_to(candidate)
	print(parent.name, " REROUTING to ", alternative_point)
	parent.queue_redraw()


func update_rerouting(delta: float) -> void:
	var distance: float = parent.global_position.distance_to(
		alternative_point
	)

	if distance <= alternative_reached_distance:
		print(parent.name, " reached alternative portal")
		reset()
		return

	# Only reset the timer when making meaningful progress.
	if previous_distance - distance >= MIN_PROGRESS:
		rerouting_timer = 0.0
		previous_distance = distance
	else:
		rerouting_timer += delta

	if rerouting_timer >= rerouting_timeout:
		print(parent.name, " rerouting stalled")
		reset()

func reset() -> void:
	if rerouting:
		parent.forces.request_path(parent.goal)
	rerouting = false
	alternative_point = Vector2.ZERO
	rerouting_timer = 0.0
	congestion_timer = 0.0
	bottleneck_detected = false
	retry_timer = retry_cooldown
	previous_distance = INF
	parent.queue_redraw()

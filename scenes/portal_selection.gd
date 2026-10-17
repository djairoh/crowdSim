extends Node
class_name PortalSelection

# Select eligible portal to avoid bottleneck
@onready var parent: CrowdAgent = get_parent().get_parent().get_parent()
@onready var rerouting: PortalRerouting = $"../PortalRerouting"

# How close a navigation path must pass to a doorway.
const PORTAL_PATH_TOLERANCE: float = 16.0
const PORTAL_BYPASS_MARGIN: float = 12.0

# Tolerance for checking navigation path endpoints.
const PATH_ENDPOINT_TOLERANCE: float = 12.0

# Print portal selection and path evaluation decisions.
@export var debug_selection: bool = true

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


# Identify the congested portal on the agent's intended route
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


func get_best_alternative_point(
	excluded_portal: Vector2 = Vector2.ZERO
) -> Vector2:
	# Get portals/doors that are currently open
	var open_portals: Array[Vector2] = (
		parent.crowd_manager.lvl.get_open_portal_positions()
	)
	
	# If there are less than 2 portals open there is no need
	if open_portals.size() < 2:
		if debug_selection:
			print(parent.name, " NO ALTERNATIVE: fewer than 2 open portals")
		return Vector2.ZERO

	var congested_portal: Vector2 = excluded_portal

	if congested_portal == Vector2.ZERO:
		congested_portal = get_congested_portal(open_portals)
	if congested_portal == Vector2.ZERO:
		if debug_selection:
			print(parent.name, " NO ALTERNATIVE: congested portal not found on original route")
		return Vector2.ZERO
	if debug_selection:
		print(parent.name, " SELECT alternative | excluded=", congested_portal, " | failed=", rerouting.failed_portals.keys())

	var navigation_map: RID = parent.get_world_2d().navigation_map
	var best_score: float = INF
	var best_point: Vector2 = Vector2.ZERO

	for portal_pos in open_portals:
		# Don't choose the congested doorway
		if portal_pos == congested_portal:
			if debug_selection:
				print(parent.name, " SKIP ", portal_pos, ": excluded congested portal")
			continue

		# Don't retry a recently failed alternative
		if rerouting.failed_portals.has(portal_pos):
			if debug_selection:
				print(parent.name, " SKIP ", portal_pos, ": temporary cooldown")
			continue

		# Current position -> alternative portal
		var path_to_portal: PackedVector2Array = (
			NavigationServer2D.map_get_path(
				navigation_map,
				parent.global_position,
				portal_pos,
				true
			)
		)

		if not is_path_usable(path_to_portal, portal_pos):
			if debug_selection:
				print(parent.name, " REJECT ", portal_pos, ": cannot reach portal")
			continue

		# Alternative portal -> original goal
		var path_to_goal: PackedVector2Array = (
			NavigationServer2D.map_get_path(
				navigation_map,
				portal_pos,
				parent.goal,
				true
			)
		)

		if not is_path_usable(path_to_goal, parent.goal):
			if debug_selection:
				print(parent.name, " REJECT ", portal_pos, ": cannot reach goal")
			continue

		# Reject alternatives that still require passing through the congested doorway.
		if (
			distance_to_path(congested_portal, path_to_portal)
			<= PORTAL_PATH_TOLERANCE
		):
			if debug_selection:
				print(parent.name, " REJECT ", portal_pos, ": path crosses excluded portal")
			continue

		if (
			distance_to_path(congested_portal, path_to_goal)
			<= PORTAL_PATH_TOLERANCE
		):
			if debug_selection:
				print(parent.name, " REJECT ", portal_pos, ": continuation crosses excluded portal")
			continue

		var total_length: float = (
			get_path_length(path_to_portal)
			+ get_path_length(path_to_goal)
		)

		if debug_selection:
			print(parent.name, " CANDIDATE ", portal_pos, " | length=", total_length)
		if total_length < best_score:
			best_score = total_length
			best_point = portal_pos

	if debug_selection:
		print(parent.name, " SELECTED ", best_point, " | length=", best_score)
	return best_point

func should_cancel_passed_portal_reroute() -> bool:
	if not rerouting.is_rerouting:
		return false

	var navigation_map: RID = parent.get_world_2d().navigation_map
	var agent_position: Vector2 = parent.global_position

	# Current position -> original goal.
	var direct_path: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		agent_position,
		parent.goal,
		true
	)

	if not is_path_usable(direct_path, parent.goal):
		return false

	# The direct route must not pass through the selected alternative.
	if distance_to_path(rerouting.alternative_point, direct_path) <= PORTAL_PATH_TOLERANCE:
		return false

	# The direct route must not pass through the original congested portal
	# or any other portal currently being avoided.
	for portal in rerouting.failed_portals.keys():
		if distance_to_path(portal, direct_path) <= PORTAL_PATH_TOLERANCE:
			return false

	# Current position -> selected alternative portal.
	var path_to_portal: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		agent_position,
		rerouting.alternative_point,
		true
	)

	if not is_path_usable(path_to_portal, rerouting.alternative_point):
		return false

	# Selected alternative portal -> original goal.
	var portal_to_goal_path: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		rerouting.alternative_point,
		parent.goal,
		true
	)

	if not is_path_usable(portal_to_goal_path, parent.goal):
		return false

	var direct_length: float = get_path_length(direct_path)

	var via_portal_length: float = (
		get_path_length(path_to_portal)
		+ get_path_length(portal_to_goal_path)
	)

	return direct_length + PORTAL_BYPASS_MARGIN < via_portal_length

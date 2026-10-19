extends Node
class_name PortalSelection

# Select eligible portal to avoid bottleneck
@onready var parent: CrowdAgent = get_parent().get_parent().get_parent()
@onready var rerouting: PortalRerouting = $"../PortalRerouting"
@onready var paths: PathEvaluation = $PathEvaluation

const PORTAL_BYPASS_MARGIN: float = 12.0

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

	if not paths.is_path_usable(current_path, parent.goal):
		return Vector2.ZERO

	var congested_portal: Vector2 = Vector2.ZERO
	var closest_distance: float = INF
	
	for portal_pos in open_portals:
		var distance: float = paths.distance_to_path(
			portal_pos,
			current_path
		)

		if distance < closest_distance:
			closest_distance = distance
			congested_portal = portal_pos

	# Congestion not associated with a portal on this route.
	if closest_distance > paths.PORTAL_PATH_TOLERANCE:
		return Vector2.ZERO

	return congested_portal

func get_best_alternative_point(
	excluded_portal: Vector2 = Vector2.ZERO
) -> Vector2:
	# Get portals/doors that are currently open
	var open_portals: Array[Vector2] = (
		parent.crowd_manager.current_level.get_open_portal_positions()
	)
	
	# If there are less than 2 portals open there is no need
	if open_portals.size() < 2:
		return Vector2.ZERO

	var congested_portal: Vector2 = excluded_portal

	if congested_portal == Vector2.ZERO:
		congested_portal = get_congested_portal(open_portals)
	if congested_portal == Vector2.ZERO:
		return Vector2.ZERO
	var navigation_map: RID = parent.get_world_2d().navigation_map
	var best_score: float = INF
	var best_point: Vector2 = Vector2.ZERO

	for portal_pos in open_portals:
		# Don't choose the congested doorway
		if portal_pos == congested_portal:
			continue

		# Don't retry a recently failed alternative
		if rerouting.failed_portals.has(portal_pos):
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
		
		# Cannot reach portal
		if not paths.is_path_usable(path_to_portal, portal_pos):
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
		
		# Cannot reach goal
		if not paths.is_path_usable(path_to_goal, parent.goal):
			continue

		# Reject alternatives that still require passing through the congested doorway.
		if (
			paths.distance_to_path(congested_portal, path_to_portal)
			<= paths.PORTAL_PATH_TOLERANCE
		):
			continue
		
		# Reject congested alternative to goal
		if (
			paths.distance_to_path(congested_portal, path_to_goal)
			<= paths.PORTAL_PATH_TOLERANCE
		):
			continue

		var total_length: float = (
			paths.get_path_length(path_to_portal)
			+ paths.get_path_length(path_to_goal)
		)

		if total_length < best_score:
			best_score = total_length
			best_point = portal_pos

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

	if not paths.is_path_usable(direct_path, parent.goal):
		return false

	# The direct route must not pass through the selected alternative.
	if paths.distance_to_path(rerouting.alternative_point, direct_path) <= paths.PORTAL_PATH_TOLERANCE:
		return false

	# The direct route must not pass through the original congested portal
	# or any other portal currently being avoided.
	for portal in rerouting.failed_portals.keys():
		if paths.distance_to_path(portal, direct_path) <= paths.PORTAL_PATH_TOLERANCE:
			return false

	# Current position -> selected alternative portal.
	var path_to_portal: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		agent_position,
		rerouting.alternative_point,
		true
	)

	if not paths.is_path_usable(path_to_portal, rerouting.alternative_point):
		return false

	# Selected alternative portal -> original goal.
	var portal_to_goal_path: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		rerouting.alternative_point,
		parent.goal,
		true
	)

	if not paths.is_path_usable(portal_to_goal_path, parent.goal):
		return false

	var direct_length: float = paths.get_path_length(direct_path)

	var via_portal_length: float = (
		paths.get_path_length(path_to_portal)
		+ paths.get_path_length(portal_to_goal_path)
	)

	return direct_length + PORTAL_BYPASS_MARGIN < via_portal_length

extends Node
class_name BottleneckAvoidance

# HiDAC bottleneck detection and portal-based rerouting.
@onready var parent: CrowdAgent = get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 8.0
const VISIBLE_AGENTS_THRESHOLD: int = 3

# How close a navigation path must pass to a doorway.
const PORTAL_PATH_TOLERANCE: float = 16.0
const PORTAL_BYPASS_MARGIN: float = 12.0

# Tolerance for checking navigation path endpoints.
const PATH_ENDPOINT_TOLERANCE: float = 12.0

# Congestion detection
@export var early_detection_distance: float = 64.0
@export var early_detection_width: float = 24.0
@export var congestion_timer_threshold: float = 1.0
@export var congestion_decay_rate: float = 0.25



var congestion_timer: float = 0.0
var bottleneck_detected: bool = false

# Avoid repeatedly requesting paths when rerouting fails.
@export var retry_cooldown: float = 2.0
var retry_timer: float = 0.0

# Rerouting
var rerouting: bool = false
var alternative_point: Vector2 = Vector2.ZERO

# Remember alternative portals that failed recently.
# Key: portal position
# Value: remaining cooldown in seconds
var failed_portals: Dictionary = {}

@export var failed_portal_cooldown: float = 15.0
@export var alternative_reached_distance: float = 12.0
@export var rerouting_timeout: float = 5.0
@export var reroute_congestion_radius: float = 48.0

# Only visible slow agents near the selected portal count.
@export var portal_local_crowd_radius: float = 48.0
@export var debug_rerouting: bool = true

var rerouting_timer: float = 0.0

@export var portal_detection_radius: float = 96.0

var previous_position: Vector2 = Vector2.ZERO

@export var min_movement: float = 1.0

func update(delta: float) -> void:
	if not parent.agent_state.is_impatient():
		if rerouting or bottleneck_detected:
			reset()
		return
	
	update_failed_portals(delta)

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

	# No valid alternative portal
	if candidate == Vector2.ZERO:
		return

	var original_portal: Vector2 = get_congested_portal(
		parent.crowd_manager.lvl.get_open_portal_positions()
	)

	start_rerouting(candidate)

	if rerouting and alternative_point == candidate:
		if original_portal != Vector2.ZERO:
			mark_portal_failed(original_portal)
			print(parent.name, " REMEMBER original congested portal ", original_portal)
	
func is_near_open_portal() -> bool:
	var portals: Array[Vector2] = (
		parent.crowd_manager.lvl.get_open_portal_positions()
	)

	for portal in portals:
		if parent.global_position.distance_to(portal) <= portal_detection_radius:
			return true

	return false

func mark_portal_failed(portal: Vector2) -> void:
	failed_portals[portal] = failed_portal_cooldown
	if debug_rerouting:
		print(parent.name, " AVOID portal ", portal, " for ", failed_portal_cooldown, "s")

func update_failed_portals(delta: float) -> void:
	for portal in failed_portals.keys():
		failed_portals[portal] -= delta

		if failed_portals[portal] <= 0.0:
			failed_portals.erase(portal)
			if debug_rerouting:
				print(parent.name, " portal cooldown expired: ", portal)


func is_route_congested() -> bool:
	var not_moving: bool = (
		parent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
		or parent.rules.stopping_rule
		or parent.rules.waiting_rule
	)

	var slow_agents: int = 0
	var slow_agents_ahead: int = 0

	# Direction the agent currently intends to move.
	var forward: Vector2 = parent.desired_velocity.normalized()

	for agent in parent.forces.visible_agents:
		if not is_instance_valid(agent):
			continue

		if agent == parent:
			continue

		var is_slow: bool = (
			agent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
			or agent.rules.stopping_rule
			or agent.rules.waiting_rule
		)

		if not is_slow:
			continue

		slow_agents += 1

		# Check whether the slow agent is directly ahead.
		if forward == Vector2.ZERO:
			continue

		var to_agent: Vector2 = (
			agent.global_position - parent.global_position
		)

		var forward_distance: float = forward.dot(to_agent)

		if forward_distance <= 0.0:
			continue

		if forward_distance > early_detection_distance:
			continue

		var lateral_distance: float = absf(
			forward.cross(to_agent)
		)

		if lateral_distance > early_detection_width:
			continue

		slow_agents_ahead += 1

	# Existing detection: agent is already stuck in congestion.
	var already_congested: bool = (
		not_moving
		and slow_agents >= VISIBLE_AGENTS_THRESHOLD
	)

	# New detection: agent sees congestion ahead,
	# even if it is still moving normally.
	var congestion_ahead: bool = (
		slow_agents_ahead >= VISIBLE_AGENTS_THRESHOLD
	)

	return (
		is_near_open_portal()
		and (already_congested or congestion_ahead)
	)
	
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
		if debug_rerouting:
			print(parent.name, " NO ALTERNATIVE: fewer than 2 open portals")
		return Vector2.ZERO

	var congested_portal: Vector2 = excluded_portal

	if congested_portal == Vector2.ZERO:
		congested_portal = get_congested_portal(open_portals)
	if congested_portal == Vector2.ZERO:
		if debug_rerouting:
			print(parent.name, " NO ALTERNATIVE: congested portal not found on original route")
		return Vector2.ZERO
	if debug_rerouting:
		print(parent.name, " SELECT alternative | excluded=", congested_portal, " | failed=", failed_portals.keys())

	var navigation_map: RID = parent.get_world_2d().navigation_map
	var best_score: float = INF
	var best_point: Vector2 = Vector2.ZERO

	for portal_pos in open_portals:
		# Don't choose the congested doorway
		if portal_pos == congested_portal:
			if debug_rerouting:
				print(parent.name, " SKIP ", portal_pos, ": excluded congested portal")
			continue

		# Don't retry a recently failed alternative
		if failed_portals.has(portal_pos):
			if debug_rerouting:
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
			if debug_rerouting:
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
			if debug_rerouting:
				print(parent.name, " REJECT ", portal_pos, ": cannot reach goal")
			continue

		# Reject alternatives that still require passing through the congested doorway.
		if (
			distance_to_path(congested_portal, path_to_portal)
			<= PORTAL_PATH_TOLERANCE
		):
			if debug_rerouting:
				print(parent.name, " REJECT ", portal_pos, ": path crosses excluded portal")
			continue

		if (
			distance_to_path(congested_portal, path_to_goal)
			<= PORTAL_PATH_TOLERANCE
		):
			if debug_rerouting:
				print(parent.name, " REJECT ", portal_pos, ": continuation crosses excluded portal")
			continue

		var total_length: float = (
			get_path_length(path_to_portal)
			+ get_path_length(path_to_goal)
		)

		if debug_rerouting:
			print(parent.name, " CANDIDATE ", portal_pos, " | length=", total_length)
		if total_length < best_score:
			best_score = total_length
			best_point = portal_pos

	if debug_rerouting:
		print(parent.name, " SELECTED ", best_point, " | length=", best_score)
	return best_point


func start_rerouting(candidate: Vector2) -> void:
	var success: bool = parent.forces.request_path(candidate)

	if not success:
		if debug_rerouting:
			print(parent.name, " PATH REQUEST FAILED: ", candidate)
		parent.forces.request_path(parent.goal)
		mark_portal_failed(candidate)
		return

	if debug_rerouting:
		print(parent.name, " REROUTE ", alternative_point if rerouting else parent.goal, " -> ", candidate, " | pos=", parent.global_position)
	alternative_point = candidate
	rerouting = true
	rerouting_timer = 0.0
	previous_position = parent.global_position
	parent.queue_redraw()

func should_cancel_passed_portal_reroute() -> bool:
	if not rerouting:
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
	if distance_to_path(alternative_point, direct_path) <= PORTAL_PATH_TOLERANCE:
		return false

	# The direct route must not pass through the original congested portal
	# or any other portal currently being avoided.
	for portal in failed_portals.keys():
		if distance_to_path(portal, direct_path) <= PORTAL_PATH_TOLERANCE:
			return false

	# Current position -> selected alternative portal.
	var path_to_portal: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		agent_position,
		alternative_point,
		true
	)

	if not is_path_usable(path_to_portal, alternative_point):
		return false

	# Selected alternative portal -> original goal.
	var portal_to_goal_path: PackedVector2Array = NavigationServer2D.map_get_path(
		navigation_map,
		alternative_point,
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

func update_rerouting(delta: float) -> void:
	if should_cancel_passed_portal_reroute():
		if debug_rerouting:
			print(
				parent.name,
				" PORTAL BYPASS: cancelling reroute to ",
				alternative_point
			)

		reset()
		return

	var distance_to_portal: float = parent.global_position.distance_to(
		alternative_point
	)

	if distance_to_portal <= alternative_reached_distance:
		print(parent.name, " REACHED portal ", alternative_point)
		reset()
		return

	# Only check congestion near the selected portal.
	if distance_to_portal <= reroute_congestion_radius:
		if is_selected_portal_congested():
			congestion_timer += delta
		else:
			congestion_timer = maxf(
				congestion_timer - delta * congestion_decay_rate,
				0.0
			)

		if congestion_timer >= congestion_timer_threshold:
			var previous_portal: Vector2 = alternative_point

			print(
				parent.name,
				" PORTAL CONGESTED ", previous_portal,
				" | distance=", distance_to_portal
			)

			# Find a replacement before marking this portal as avoided.
			var candidate: Vector2 = get_best_alternative_point(
				previous_portal
			)

			congestion_timer = 0.0

			if candidate != Vector2.ZERO:
				var success: bool = parent.forces.request_path(candidate)

				if success:
					mark_portal_failed(previous_portal)

					print(
						parent.name,
						" SWITCH ", previous_portal,
						" -> ", candidate
					)

					alternative_point = candidate
					rerouting_timer = 0.0
					previous_position = parent.global_position
					parent.queue_redraw()
					return

				# Restore the previous route if switching failed.
				parent.forces.request_path(previous_portal)

			print(
				parent.name,
				" NO OTHER PORTAL: continuing toward ",
				previous_portal
			)
	else:
		congestion_timer = 0.0

	# Preserve existing stall detection.
	var movement: float = parent.global_position.distance_to(
		previous_position
	)

	if movement >= min_movement:
		rerouting_timer = 0.0
		previous_position = parent.global_position
	else:
		rerouting_timer += delta

	if rerouting_timer >= rerouting_timeout:
		print(parent.name, " REROUTE STALLED at ", alternative_point)
		mark_portal_failed(alternative_point)
		reset()
		
func is_selected_portal_congested() -> bool:
	var slow_agents_ahead: int = 0
	var forward: Vector2 = parent.desired_velocity.normalized()

	if forward == Vector2.ZERO:
		return false

	for agent in parent.forces.visible_agents:
		if not is_instance_valid(agent) or agent == parent:
			continue

		if not agent is CrowdAgent:
			continue

		# Only consider agents near the selected doorway.
		if agent.global_position.distance_to(
			alternative_point
		) > portal_local_crowd_radius:
			continue

		var is_slow: bool = (
			agent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
			or agent.rules.stopping_rule
			or agent.rules.waiting_rule
		)

		if not is_slow:
			continue

		var to_agent: Vector2 = (
			agent.global_position - parent.global_position
		)

		var forward_distance: float = forward.dot(to_agent)

		if forward_distance <= 0.0:
			continue

		if forward_distance > early_detection_distance:
			continue

		var lateral_distance: float = absf(
			forward.cross(to_agent)
		)

		if lateral_distance > early_detection_width:
			continue

		slow_agents_ahead += 1

	return slow_agents_ahead >= VISIBLE_AGENTS_THRESHOLD


func reset() -> void:
	if debug_rerouting and rerouting:
		print(parent.name, " RESET reroute ", alternative_point, " -> original goal ", parent.goal)
	if rerouting:
		parent.forces.request_path(parent.goal)
	rerouting = false
	alternative_point = Vector2.ZERO
	rerouting_timer = 0.0
	congestion_timer = 0.0
	bottleneck_detected = false
	retry_timer = retry_cooldown
	previous_position = Vector2.ZERO
	parent.queue_redraw()

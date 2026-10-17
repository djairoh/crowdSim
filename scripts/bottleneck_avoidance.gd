extends Node
class_name BottleneckAvoidance

# HiDAC bottleneck detection and portal-based rerouting.
@onready var parent: CrowdAgent = get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 8.0
const VISIBLE_AGENTS_THRESHOLD: int = 3

# How close a navigation path must pass to a doorway.
const PORTAL_PATH_TOLERANCE: float = 16.0

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
var rerouting_timer: float = 0.0
var previous_distance: float = INF
const MIN_PROGRESS: float = 0.1

@export var portal_detection_radius: float = 96.0

# Penalize busy alternative portals when comparing routes.
@export var portal_crowd_radius: float = 48.0
@export var portal_congestion_penalty: float = 100.0

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

	if candidate == Vector2.ZERO:
		print(parent.name, " found no valid alternative portal")
		return

	print(parent.name, " BEST alternative: ", candidate)
	start_rerouting(candidate)
	
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

	print(parent.name, " temporarily avoiding portal ", portal)


func update_failed_portals(delta: float) -> void:
	for portal in failed_portals.keys():
		failed_portals[portal] -= delta

		if failed_portals[portal] <= 0.0:
			failed_portals.erase(portal)


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


func get_portal_congestion(portal_pos: Vector2) -> int:
	var congested_agents: int = 0

	for agent in get_tree().get_nodes_in_group("agent"):
		if not is_instance_valid(agent) or agent == parent:
			continue
		if not agent is CrowdAgent:
			continue
		if agent.global_position.distance_to(portal_pos) > portal_crowd_radius:
			continue
		if (
			agent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
			or agent.rules.stopping_rule
			or agent.rules.waiting_rule
		):
			congested_agents += 1

	return congested_agents


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

	var best_score: float = INF
	var best_point: Vector2 = Vector2.ZERO

	for portal_pos in open_portals:
		# Don't choose the congested doorway.
		if portal_pos == congested_portal:
			continue

		# Don't retry a recently failed alternative.
		if failed_portals.has(portal_pos):
			print(parent.name, " SKIPPING failed portal: ", portal_pos)
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
			print(parent.name, " rejected ", portal_pos, ": unreachable from agent")

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
			print(parent.name, " rejected ", portal_pos, ": cannot reach goal")

			continue

		# Reject alternatives that still require passing
		# through the congested doorway.
		if (
			distance_to_path(congested_portal, path_to_portal)
			<= PORTAL_PATH_TOLERANCE
		):
			print(parent.name, " rejected ", portal_pos, ": route passes congested door")

			continue

		if (
			distance_to_path(congested_portal, path_to_goal)
			<= PORTAL_PATH_TOLERANCE
		):
			print(parent.name, " rejected ", portal_pos, ": continuation passes congested door")

			continue

		var total_length: float = (
			get_path_length(path_to_portal)
			+ get_path_length(path_to_goal)
		)

		var congestion: int = get_portal_congestion(portal_pos)
		var score: float = (
			total_length
			+ congestion * portal_congestion_penalty
		)

		print(
			parent.name,
			" portal: ", portal_pos,
			" | length: ", total_length,
			" | congestion: ", congestion,
			" | score: ", score
		)

		if score < best_score:
			best_score = score
			best_point = portal_pos

	return best_point


func start_rerouting(candidate: Vector2) -> void:
	var success: bool = parent.forces.request_path(candidate)

	if not success:
		parent.forces.request_path(parent.goal)
		mark_portal_failed(candidate)
		print(parent.name, " failed to reroute to ", candidate)
		return

	alternative_point = candidate
	rerouting = true
	rerouting_timer = 0.0
	previous_distance = parent.global_position.distance_to(candidate)
	previous_position = parent.global_position
	print(parent.name, " REROUTING to ", alternative_point)
	parent.queue_redraw()


func update_rerouting(delta: float) -> void:
	if parent.global_position.distance_to(
		alternative_point
	) <= alternative_reached_distance:
		print(parent.name, " reached alternative portal")
		reset()
		return

	var movement: float = parent.global_position.distance_to(
		previous_position
	)

	if movement >= min_movement:
		rerouting_timer = 0.0
		previous_position = parent.global_position
	else:
		rerouting_timer += delta

	if rerouting_timer >= rerouting_timeout:
		print(parent.name, " rerouting stalled at ", alternative_point)
		mark_portal_failed(alternative_point)
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
	previous_position = Vector2.ZERO
	parent.queue_redraw()

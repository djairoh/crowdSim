extends Node
class_name CongestionDetection

# HiDAC bottleneck detection
@onready var parent: CrowdAgent = get_parent().get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 8.0
const VISIBLE_AGENTS_THRESHOLD: int = 3

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

# Only visible slow agents near the selected portal count.
@export var portal_local_crowd_radius: float = 48.0
@export var portal_detection_radius: float = 96.0

func update(delta: float) -> void:
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

	if not bottleneck_detected:
		bottleneck_detected = true
		parent.queue_redraw()

func is_near_open_portal() -> bool:
	var portals: Array[Vector2] = (
		parent.crowd_manager.lvl.get_open_portal_positions()
	)

	for portal in portals:
		if parent.global_position.distance_to(portal) <= portal_detection_radius:
			return true

	return false
	
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

		if not is_agent_slow(agent):
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
	
func is_selected_portal_congested(portal: Vector2) -> bool:
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
			portal
		) > portal_local_crowd_radius:
			continue

		if not is_agent_slow(agent):
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

func is_agent_slow(agent: CrowdAgent) -> bool:
	return (
		agent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
		or agent.rules.stopping_rule
		or agent.rules.waiting_rule
	)

func start_retry_cooldown() -> void:
	retry_timer = retry_cooldown

func reset() -> void:
	congestion_timer = 0.0
	bottleneck_detected = false
	start_retry_cooldown()
	parent.queue_redraw()

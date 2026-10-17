extends Node
class_name PortalRerouting

# HiDAC bottleneck detection and portal-based rerouting.
@onready var parent: CrowdAgent = get_parent().get_parent().get_parent()
@onready var detection: CongestionDetection = $"../CongestionDetection"
@onready var selection: PortalSelection = $"../PortalSelection"

# Congestion detection
@export var congestion_timer_threshold: float = 1.0
@export var congestion_decay_rate: float = 0.25
var congestion_timer: float = 0.0

# Rerouting
var is_rerouting: bool = false
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
@export var debug_rerouting: bool = true

var rerouting_timer: float = 0.0
var previous_position: Vector2 = Vector2.ZERO

@export var min_movement: float = 1.0

func try_start_rerouting() -> void:
	var candidate: Vector2 = selection.get_best_alternative_point()

	if candidate == Vector2.ZERO:
		return

	var original_portal: Vector2 = selection.get_congested_portal(
		parent.crowd_manager.lvl.get_open_portal_positions()
	)

	start_rerouting(candidate)

	if is_rerouting and alternative_point == candidate:
		if original_portal != Vector2.ZERO:
			mark_portal_failed(original_portal)
			if debug_rerouting:
				print(
					parent.name,
					" REMEMBER original congested portal ",
					original_portal
				)

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

func start_rerouting(candidate: Vector2) -> void:
	var success: bool = parent.forces.request_path(candidate)

	if not success:
		if debug_rerouting:
			print(parent.name, " PATH REQUEST FAILED: ", candidate)
		parent.forces.request_path(parent.goal)
		mark_portal_failed(candidate)
		return

	if debug_rerouting:
		print(parent.name, " REROUTE ", alternative_point if is_rerouting else parent.goal, " -> ", candidate, " | pos=", parent.global_position)
	alternative_point = candidate
	is_rerouting = true
	rerouting_timer = 0.0
	previous_position = parent.global_position
	parent.queue_redraw()

func update_rerouting(delta: float) -> void:
	if selection.should_cancel_passed_portal_reroute():
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
		if detection.is_selected_portal_congested(alternative_point):
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
			var candidate: Vector2 = selection.get_best_alternative_point(
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
		

func reset() -> void:
	if debug_rerouting and is_rerouting:
		print(
			parent.name,
			" RESET reroute ",
			alternative_point,
			" -> original goal ",
			parent.goal
		)

	if is_rerouting:
		parent.forces.request_path(parent.goal)

	is_rerouting = false
	alternative_point = Vector2.ZERO
	rerouting_timer = 0.0
	congestion_timer = 0.0
	previous_position = Vector2.ZERO
	
	detection.reset()
	parent.queue_redraw()

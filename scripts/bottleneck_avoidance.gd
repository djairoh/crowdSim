extends Node
class_name BottleneckAvoidance

# Detect bottlenecks in crowds, and 
# TODO: find alternative route
@onready var parent: CrowdAgent = get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 5.0
const VISIBLE_AGENTS_THRESHOLD: int = 6

# Timer to ensure congestion lasted long enoug
@export var congestion_timer_threshold: float = 2.0
@export var congestion_decay_rate: float = 0.25
var congestion_timer: float = 0.0
var bottleneck_detected: bool = false

# Alternative path for agent to reroute to
@export var alternative_distance: float = 72.0 # 72px/24px = 3m
@export var max_nav_snap_distance: float = 12.0

var alt_path_goal: Vector2 = Vector2.ZERO


func update(delta):
	if not parent.agent_state.is_impatient():
		bottleneck_detected = false
		congestion_timer = 0.0
		return
	
	# Check congestion	
	if is_route_congested():
		congestion_timer += delta
	else: 
		# when congestion disappear, slowly reduce timer
		congestion_timer = max(congestion_timer - delta * congestion_decay_rate, 0.0)
	
	# Detect Bottleneck
	if congestion_timer >= congestion_timer_threshold:
		if not bottleneck_detected:
			bottleneck_detected = true
			parent.queue_redraw()

			print(parent.name, " detects a bottleneck! Now lets find cadidate points!!!")
			# Find alternative points to pivot navigation to
			var alternative_points := get_alternative_points()

			for point in alternative_points:
				print(parent.name, " candidate: ", point)
				
			# TODO: Find best candidate points and check if you can actually reach there
			# TODO: Find the path to the best point
			# TODO: Navigate to the best point
				
	# Find alternative pathway
	
	# Reset
	if congestion_timer <= 0.0:
		if bottleneck_detected:
			bottleneck_detected = false
			parent.queue_redraw()

func is_route_congested() -> bool:
	# Check if you are stuck
	# check your speed
	var not_moving: bool = (
		parent.velocity.length() < VELOCITY_LENGTH_THRESHOLD
		or parent.rules.stopping_rule
		or parent.rules.waiting_rule
	)
	
	# check how many agents are stuck infront of you?
	var blocked_by_others: bool = (
		len(parent.forces.visible_agents) 
		>= VISIBLE_AGENTS_THRESHOLD
	)
	
	return not_moving and blocked_by_others
	
func get_alternative_points() -> Array[Vector2]:
	var points :Array[Vector2] = []
	
	# TODO: Add possible alternative points
	
	# TODO: get current goal direction
	var forward: Vector2 = parent.global_position.direction_to(parent.goal)
	
	if forward.length_squared() <= 0.0001:
		return points
	
	# TODO: find direction left and right of goal
	var right := Vector2(-forward.y, forward.x)
	
	# Search mostly sideways, but a little forward.
	var new_directions: Array[Vector2] = [
		(forward * 0.5 + right).normalized(),
		(forward * 0.5 - right).normalized()
	]
	
	# get 2d map
	var navigation_map: RID = parent.get_world_2d().navigation_map
	
	for new_direction in new_directions:
		var candidate_point = (
			parent.global_position 
			+ new_direction 
			* alternative_distance
		)
		
		# Get the closest point in map
		var nav_point := NavigationServer2D.map_get_closest_point(navigation_map, candidate_point)
	
		# Don't include nav point that are too far
		if nav_point.distance_to(candidate_point) > max_nav_snap_distance:
			continue
		
		points.append(nav_point)
	
	return points
	
func get_alternative_route()-> Vector2:
	# TODO: Find a free area? how
	var new_goal: Vector2 = Vector2.ZERO
	return new_goal
		
func avoid_bottleneck()->void:
	if is_route_congested():
		print("route is congested bruh, go find another way")
		
		# TODO: Find a free area? how
		var new_goal: Vector2 = get_alternative_route()
		parent.forces.request_path(new_goal)
		
func reset()->void:
	bottleneck_detected = false
	congestion_timer = 0.0

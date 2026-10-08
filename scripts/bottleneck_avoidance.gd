extends Node
class_name BottleneckAvoidance

# Detect bottlenecks in crowds, and find alternative route
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

# Rerouting
var rerouting: bool = false
var alternative_point: Vector2 = Vector2.ZERO
# How close the agent must get to the temporary waypoint
# before continuing toward its original goal.
@export var alternative_reached_distance: float = 12.0


func update(delta):
	if not parent.agent_state.is_impatient():
		reset()
		return
	
	if rerouting:
		update_rerouting()
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
			# Find best alternative point from a list of candidate points
			# and check if you can actually reach there
			var candidate_point := get_best_alternative_point()
			if candidate_point != Vector2.ZERO:
				print( parent.name, " BEST alternative: ", candidate_point)
				
				# Navigate to the best point
				start_rerouting(candidate_point)
			else:
				print(parent.name, " found no alternative")
	
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
	
	# get current goal direction
	var forward: Vector2 = parent.global_position.direction_to(parent.goal)
	
	if forward.length_squared() <= 0.0001:
		return points
	
	# find direction left and right of goal
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
	
# Increment total distance of a path
func get_path_length(path: PackedVector2Array)->float:
	var total_length = 0.0
	for i in range(path.size() - 1):
		# increment distance from current path to the next
		total_length += path[i].distance_to(path[i+1])
	return total_length

# Get best alternative point and shortest path
# TODO: Get best point that actually circumvent around the crowd
func get_best_alternative_point()->Vector2:
	var candidate_points := get_alternative_points()
	
	if candidate_points.is_empty():
		return Vector2.ZERO
	
	var navigation_map: RID = parent.get_world_2d().navigation_map

	# Best path is the shortest path
	var shortest_path_length: float = INF
	var shortest_path_point: Vector2 = Vector2.ZERO
	
	for candidate_point in candidate_points:
		# Path from current point to candidate point
		var path_to_candidate := NavigationServer2D.map_get_path(
			navigation_map,
			parent.global_position,
			candidate_point,
			true
		)
		
		# No usable navigation path to this candidate.
		if path_to_candidate.size() < 2:
			continue
	
		# Path from candidate to actual goal
		var path_to_goal := NavigationServer2D.map_get_path(
			navigation_map,
			candidate_point,
			parent.goal,
			true
		)
		
		# No usable navigation path to final goal.
		if path_to_goal.size() < 2:
			continue
			
		var total_length = (
			get_path_length(path_to_candidate) 
			+ get_path_length(path_to_goal)
		)
		
		print(
			parent.name,
			" candidate_point ",
			candidate_point,
			" route length = ",
			total_length
		)
	
		if total_length < shortest_path_length:
			shortest_path_length = total_length
			shortest_path_point = candidate_point
	
	return shortest_path_point
	
func start_rerouting(candidate: Vector2) -> void:
	
	# No path found
	if not parent.forces.request_path(candidate):
		return
	
	alternative_point = candidate
	rerouting = true
	
	print(parent.name, " REROUTING to ", alternative_point)
	parent.queue_redraw()
	
func update_rerouting() -> void:
	var distance = parent.global_position.distance_to(alternative_point)
	
	if distance <= alternative_reached_distance:
		print(parent.name, " reached alternative point")
		
		# Reset rerouting, bottleneck and congestion check
		reset()

# Reset rerouting, bottleneck and congestion check
func reset() -> void:
	# cancel rerouting and navigate to original goal
	if rerouting:
		parent.forces.request_path(parent.goal)

	rerouting = false
	alternative_point = Vector2.ZERO
	congestion_timer = 0.0
	bottleneck_detected = false
	parent.queue_redraw()

extends Node
class_name BottleneckAvoidance

# TODO: Detect bottlenecks in crowds, and find alternative route
@onready var parent: CrowdAgent = get_parent().get_parent()

const VELOCITY_LENGTH_THRESHOLD: float = 5.0
const VISIBLE_AGENTS_THRESHOLD: int = 6

# Timer to ensure congestion lasted long enoug
@export var congestion_timer_threshold: float = 2.0
@export var congestion_decay_rate: float = 0.25
var congestion_timer: float = 0.0
var bottleneck_detected: bool = false

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
			print(parent.name, " detects a bottleneck! Now lets move!!!")
	
	if congestion_timer <= 0.0:
		reset()

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
	

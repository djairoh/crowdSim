extends Node2D
class_name Rules
# Class to calculate the StoppingRule (fix shaking behaviour) and WaitingRule (queuing)

@onready var parent: CrowdAgent = get_parent()

# Stopping and Waiting Rule
var stopping_rule: bool = false
var waiting_rule: bool = false

# Defining our own stopping timer values to avoid deadlocks
var stopping_timer: float = 0.0
@export var stopping_time_min: float = 0.1
@export var stopping_time_max: float = 0.3

# Waiting rule timer
var waiting_timer: float = 0.0
@export var waiting_time_min: float = 0.1
@export var waiting_time_max: float = 0.3

@export var waiting_alignment_threshold: float = 0.7
@export var waiting_lateral_distance: float = 12.0

var visible_agents: Dictionary = {}

# TODO: Notes: waiting rule area depends on personality
# Normal agent: largest
# Panic agent: small, no respect

func update_rules(delta: float) -> void:
	update_stopping_rule(delta)
	update_waiting_rule(delta)

func update_stopping_rule(delta: float) -> void:
	# Count down after stopping
	if stopping_rule:
		stopping_timer -= delta
		
		if stopping_timer <= 0.0:
			stopping_rule = false

		return
	# Apply StoppingRule when other-agent repulsion acts against
	# the agent's desired direction of movement.
	var backward_repulsion: bool = parent.desired_velocity.dot(parent.repulsion.F_r_ot) < 0.0 
	if backward_repulsion and !parent.agent_state.is_panic():
		stopping_rule = true
		# start timer from a random small interval
		stopping_timer = randf_range(stopping_time_min, stopping_time_max)

func update_waiting_rule(delta: float) -> void:
	var waiting_condition: bool = should_wait()
	# Count down after waiting
	if waiting_rule:
		waiting_timer -= delta
		
		if not waiting_condition or waiting_timer <= 0.0:
			waiting_rule = false
		return
	
	if waiting_condition:
		waiting_rule = true
		waiting_timer = randf_range(waiting_time_min, waiting_time_max)

func should_wait() -> bool:
	if parent.agent_state.is_panic():
		return false
		
	if parent.agent_state.is_impatient() and parent.behaviours.bottleneck_avoidance.rerouting.is_rerouting:
		return false
		
	var v_i: Vector2 = parent.desired_velocity

	if v_i.length_squared() <= 0.0001:
		return false

	var forward: Vector2 = v_i.normalized()

	for other_agent in visible_agents:
		if not is_instance_valid(other_agent):
			continue

		if other_agent.agent_state.is_fallen():
			continue

		var v_j: Vector2 = other_agent.desired_velocity

		if v_j.length_squared() <= 0.0001:
			continue

		var to_j: Vector2 = (
			other_agent.global_position
			- parent.global_position
		)

		# Other agent must be ahead.
		var forward_distance: float = forward.dot(to_j)

		if forward_distance <= 0.0:
			continue

		# Other agent must be close to our intended movement line.
		var lateral_distance: float = absf(
			forward.cross(to_j)
		)

		if lateral_distance > waiting_lateral_distance:
			continue

		# Agents must be moving in sufficiently similar directions.
		var alignment: float = forward.dot(v_j.normalized())

		if alignment >= waiting_alignment_threshold:
			return true

	return false

func _on_waiting_area_body_entered(body: Node2D) -> void:
	if body == parent:
		return

	if body.is_in_group("agent"):
		visible_agents.get_or_add(body, null)

func _on_waiting_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("agent"):
		visible_agents.erase(body)

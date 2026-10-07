extends Node2D

# This class handles the different types of agent states and remove coupling from 
# agent class trying to handle states
# TODO: Update sprite colors
class_name AgentState

@onready var parent: CrowdAgent = get_parent()
@onready var sprite: Sprite2D = get_parent().get_node("Sprite2D")
@onready var panic_area: Area2D = $PanicArea


enum states {
	NORMAL,
	PANIC,
	IMPATIENT,
	FALLEN,
}
@export var current_state = states.NORMAL

var panic_level: float = 0.0

const PANIC_THRESHOLD: float = 1.0
const PANIC_PROPAGATION_RATE: float = 0.5
const DENSITY_THRESHOLD: int = 8
const DENSITY_PANIC_RATE: float = 0.05

func update(delta: float) -> void:
	update_panic(delta)

# Set the states
func set_normal() -> void:
	current_state = states.NORMAL
	sprite.modulate = Color.LIGHT_BLUE
	
func set_panic() -> void:
	current_state = states.PANIC
	sprite.modulate = Color.RED

func set_impatient() -> void:
	current_state = states.IMPATIENT
	sprite.modulate = Color.YELLOW
	
func set_fallen() -> void:
	current_state = states.FALLEN
	sprite.modulate = Color.WEB_PURPLE
	
# Check agent state
func is_normal() -> bool:
	return current_state == states.NORMAL

func is_panic() -> bool:
	return current_state == states.PANIC

func is_impatient() -> bool:
	return current_state == states.IMPATIENT
	
func is_fallen() -> bool:
	return current_state == states.FALLEN
	
# Turn into a panicked agent if conditions are met (communication, pushing, density panic)
# NOTE: These conditions we defined ourselves and based loosely on the paper, 
# since the paper did not specify the formulas for it.
func update_panic(delta: float) -> void:
	if is_fallen() or is_panic():
		return
	
	# Keep track of panic neighbours
	var panicked_neighbours: int = 0
	var nearby_agents: int = 0
	
	for body in panic_area.get_overlapping_bodies():
		if not body is CrowdAgent or body == parent:
			continue
			
		var other_agent: CrowdAgent = body
			
		if not is_instance_valid(other_agent):
			continue
			
		# Get other agents except fallen ones
		if not other_agent.agent_state.is_fallen():
			nearby_agents += 1
			
		if other_agent.agent_state.is_panic():
			panicked_neighbours += 1
			
	var communication_panic: float = 0.0
	var pushing_panic: float = 0.0
	var density_panic: float = 0.0
			
	# Communication panic: Increase panic level by the number of neighbours, panic rate and time change
	if panicked_neighbours > 0:
		communication_panic = panicked_neighbours * PANIC_PROPAGATION_RATE * delta
		
	# Pushing panic: Perceived increase of number of people pushing	
	var pushing_count: int = parent.repulsion.agent_repulsion_forces.size()
	if pushing_count >= 2:
		pushing_panic = 0.2 * pushing_count * delta
		
	# Density panic: crowded local area increases panic.
	if nearby_agents >= DENSITY_THRESHOLD:
		var excess_density: int = nearby_agents - DENSITY_THRESHOLD + 1

		density_panic = (
			excess_density
			* DENSITY_PANIC_RATE
			* delta
		)
		
	panic_level += communication_panic + pushing_panic + density_panic
			
	if panic_level > PANIC_THRESHOLD:
		set_panic()

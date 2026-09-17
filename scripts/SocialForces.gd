extends Node
class_name SocialForces

# REFACTOR: this whole thing needs massive work; i yoinked this implementation from the internet, and its bad.
# Basically we need to implement social forces from scratch.
# this doesnt even include wall repulsion stuff lol

# default force params
# FIXME: these should be adaptive
var goal_force_weight: float = 1.0
var repulsion_force_weight: float = 1.5
var agent_repulsion_radius: float = 50.0
var agent_repulsion_strength: float = 100.0
var max_force_magnitude: float = 500.0

# convenience data class
class ForceVector:
	var goal_force: Vector2 = Vector2.ZERO
	var repulsion_force: Vector2 = Vector2.ZERO
	var total_force: Vector2 = Vector2.ZERO

	func get_total() -> Vector2:
		total_force = goal_force * 1.5 + repulsion_force * 0.5
		return total_force.limit_length(500)


# Goal force pulls agent towards waypoint 
func calculate_goal_force(agent_pos: Vector2, target_pos: Vector2, max_speed: float) -> Vector2:
	var direction = (target_pos - agent_pos).normalized()
	var desired_velocity = direction * max_speed
	var force = desired_velocity  # FIXME: doesnt account for current velocity
	return force * goal_force_weight


# repulsion between agents
func calculate_agent_repulsion(agent_pos: Vector2, nearby_agents: Array[Vector2], agent_radius: float = 10.0) -> Vector2:
	var repulsion = Vector2.ZERO

	for other_pos in nearby_agents:
		var distance = agent_pos.distance_to(other_pos)
		if distance < agent_repulsion_radius and distance > 0.1:
			var direction = (agent_pos - other_pos).normalized()
			var strength = agent_repulsion_strength * (1.0 - (distance / agent_repulsion_radius))
			repulsion += direction * strength

	return repulsion * repulsion_force_weight


# repulsion from obstacles
func calculate_obstacle_repulsion(agent_pos: Vector2, obstacles: Array[Vector2], obstacle_radius: float = 20.0) -> Vector2:
	var repulsion = Vector2.ZERO

	for obstacle_pos in obstacles:
		var distance = agent_pos.distance_to(obstacle_pos)

		if distance < obstacle_radius and distance > 0.1:
			var direction = (agent_pos - obstacle_pos).normalized()
			var strength = 200.0 * (1.0 - (distance / obstacle_radius))
			repulsion += direction * strength

	return repulsion


# main force calc combines all sources
func calculate_total_force(agent_pos: Vector2, target_pos: Vector2, nearby_agents: Array[Vector2], 
							nearby_obstacles: Array[Vector2], max_speed: float = 100.0) -> ForceVector:
	var forces = ForceVector.new()

	forces.goal_force = calculate_goal_force(agent_pos, target_pos, max_speed)
	forces.repulsion_force = calculate_agent_repulsion(agent_pos, nearby_agents)
	forces.repulsion_force += calculate_obstacle_repulsion(agent_pos, nearby_obstacles)

	return forces

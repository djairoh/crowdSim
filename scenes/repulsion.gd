extends Node2D

# Class to calculate the agent repulsion to the Wall, Other Obstacles and Other agents.
# Each component is calculated separately, but the global repulsion can be requested using get_total_repulsion()

# HiDAC Repulsion forces Eq. 10 - 13

# Obtained given an agent diameter represents 0.5m in real life.
# Given agent diameter = 12 pixels
# 12 / 0.5 = 24 
const PIXELS_PER_METER: float = 24

const AGENT_RADIUS_PIXEL: float = 6.0
const AGENT_RADIUS_M: float = 0.25

# Total repulsion force of agent i
# Result of Eq. (10)
var r_i: Vector2 = Vector2.ZERO

# Repuslion Forces
var F_r_wa: Vector2 = Vector2.ZERO
var F_r_ob: Vector2 = Vector2.ZERO
var F_r_ot: Vector2 = Vector2.ZERO

# Agent's Repulsion Area collision box radius currently set to the same size as Agent radius
# Agent's personal space (ε_i)
@export var personal_space_pixel: float = 0.0
@export var personal_space_m: float = 0.0

@onready var parent: CrowdAgent = get_parent()

# track overlapping obstacles and agents
var overlapping_obstacles: Dictionary = {}
var overlapping_agents: Dictionary = {}

# TODO: Maybe put this in a utils file somewhere...
func pixels_to_meters(pixels: float) -> float:
	return pixels / PIXELS_PER_METER

func meters_to_pixels(meters: float) -> float:
	return meters * PIXELS_PER_METER

var p_i: Vector2 = parent.global_position

func _update_repulsion():
	# update all forces. makes sure we're on the same page (will be useful if we later decide we don't want to update all forces every frame)
	calculate_wall_repulsion()
	calculate_object_repulsion()
	calculate_other_agent_repulsion()

# TODO: Calcualte total repulsion
func get_total_repulsion(update: bool = false) -> Vector2:
	if update:
		_update_repulsion()
	
	# Lambda gives walls/static obstacles priority over agents.
	var lambda: float = 1.0
	# Paper explicitly states lambda = 0.3 when wall or obstacle repulsion exists
	if F_r_wa.length_squared() >=0 or F_r_ob.length_squared() >=0:
		lambda = 0.3
	
	# Eq. (10)
	return (F_r_wa + F_r_ot + F_r_ob*lambda).normalized()

# TODO: Wall repulsion
func calculate_wall_repulsion():
	# Eq. (10)
	F_r_wa = Vector2.ZERO

# TODO: Other object repulsion. get object actual radii?
func calculate_object_repulsion():
	for obstacle in overlapping_obstacles:
		if not is_instance_id_valid(obstacle):
			continue
		
		var p_k: Vector2 = obstacle.global_position
		
		# p_i - p_k
		var away_vector: Vector2 = p_i - p_k
		
		# Distance between center of agent i and obstacle k
		var d_ki_m: float = pixels_to_meters(away_vector.length())
		if d_ki_m <= 0.0001:
			continue
		
		# Radii of agent
		var r_i_m: float = AGENT_RADIUS_M
		
		# Radii of obstacle k
		# TODO: get an actual one
		var r_d_m: float = AGENT_RADIUS_M
		
		# Calculating amount of overlap
		# r_i + ε_i + r_d - d_ki
		var overlap_m: float = r_i_m + personal_space_m + r_d_m - d_ki_m
		
		 # Only check if personal space overlap
		if overlap_m <= 0.0:
			continue
			
		# Calculating direction away from k
		# (p_i - p_k) / d_ji is the direction from k toward i
		# var direction_away = away_vector / d_ki_m
		var direction_away = away_vector.normalized()
		
		# Eq. (12)
		F_r_ob += direction_away * overlap_m
	return

# Other agent repulsion
func calculate_other_agent_repulsion():
	for other_agent in overlapping_agents:
		if not is_instance_id_valid(other_agent):
			continue
			
		if other_agent == parent:
			continue
		
		var p_j: Vector2 = other_agent.global_position
		
		# p_i - p_j
		var away_vector: Vector2 = p_i - p_j
		
		# Distance between center of agent i and j
		var d_ji_m: float = pixels_to_meters(away_vector.length())
		if d_ji_m <= 0.0001:
			continue
		
		# Radii of agents
		var r_i_m: float = AGENT_RADIUS_M
		var r_j_m: float = AGENT_RADIUS_M
		
		# Calculating amount of overlap
		# r_i + ε_i + r_j - d_ji
		var overlap_m: float = r_i_m + personal_space_m + r_j_m - d_ji_m
		
		 # Only check if personal space overlap
		if overlap_m <= 0.0:
			continue
			
		# Calculating direction away from j
		# (p_i - p_j) / d_ji is the direction from j toward i
		# var direction_away = away_vector / d_ji_m
		var direction_away = away_vector.normalized()
		
		# Eq. (13)
		F_r_ot += direction_away * overlap_m
	
func _on_repulsion_area_2d_body_entered(body: Node2D) -> void:
	if body == parent:
		return
	if body.is_in_group("agent"):
		overlapping_agents.get_or_add(body, null)
	elif body.is_in_group("obstacle"):
		overlapping_obstacles.get_or_add(body, null)

func _on_repulsion_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("agent"):
		overlapping_agents.erase(body)
	elif body.is_in_group("obstacle"):
		overlapping_obstacles.erase(body)

extends Node2D
class_name Repulsion

# Class to calculate the agent repulsion to the Wall, Other Obstacles and Other agents.
# This class is also responsible for the pushing behaviour
# Each component is calculated separately, but the global repulsion can be requested using get_total_repulsion()

# HiDAC Repulsion forces Eq. 10 - 13

const AGENT_RADIUS: float = 6.0

# Repuslion Forces
var F_r_wa: Vector2 = Vector2.ZERO
var F_r_ob: Vector2 = Vector2.ZERO
var F_r_ot: Vector2 = Vector2.ZERO

# Retain agent repusion forces
var agent_repulsion_forces: Array[Vector2] = []
var min_agent_repulsion_count: int = 3

# Falling force and alignment threshold
@export var fall_force_threshold: float = 5.0
@export_range(-1.0, 1.0) var fall_alignment_threshold: float = 0.7

@onready var parent: CrowdAgent = get_parent()
@onready var repulsion_collision: CollisionShape2D = $RepulsionArea/CollisionShape2D
@onready var wall_repulsion_rays: Node2D = $WallRepulsionRays

# Agent's Repulsion Area collision box radius
# Agent's personal space (ε_i)
# ε_i
@export var personal_space: float = 4.0:
	set(value):
		value = max(value, 0.0)

		if is_equal_approx(personal_space, value):
			return

		personal_space = value

		if is_node_ready():
			_update_repulsion_area()
			_update_wall_ray_length()
			
@export var normal_personal_space: float = 4.0
@export var panic_personal_space: float = 0.0
@export var impatient_personal_space: float = 2.0

func _update_personal_space() -> void:
	if parent.agent_state.is_panic():
		personal_space = panic_personal_space
	elif parent.agent_state.is_impatient():
		personal_space = impatient_personal_space
	else:
		personal_space = normal_personal_space
		
# track overlapping obstacles and agents
var overlapping_obstacles: Dictionary = {}
var overlapping_agents: Dictionary = {}

func _ready() -> void:
	_update_repulsion_area()
	_update_wall_ray_length()

# Update agent repulsion area
func _update_repulsion_area() -> void:
	var shape := repulsion_collision.shape as CircleShape2D

	if shape == null:
		return

	shape.radius = AGENT_RADIUS + personal_space

func _update_wall_ray_length() -> void:
	var repulsion_range: float = AGENT_RADIUS + personal_space
	for child in wall_repulsion_rays.get_children():
		var ray = child as RayCast2D
		if ray == null:
			continue
		ray.target_position = ray.target_position.normalized() * repulsion_range
	
func _update_repulsion():
	_update_personal_space()
	# update all forces. makes sure we're on the same page (will be useful if we later decide we don't want to update all forces every frame)
	calculate_wall_repulsion()
	calculate_object_repulsion()
	calculate_other_agent_repulsion()
	
	# falling agents
	if not parent.agent_state.is_fallen() and should_fall():
		parent.behaviours.falling.fall()
	
func get_total_repulsion(update: bool = false) -> Vector2:
	if update:
		_update_repulsion()
	
	# Lambda gives walls/static obstacles priority over agents.
	var lambda: float = 1.0
	# Paper explicitly states lambda = 0.3 when wall or obstacle repulsion exists
	if F_r_wa.length_squared() > 0 or F_r_ob.length_squared() > 0:
		lambda = 0.3
	
	if (
		F_r_wa.length_squared() > 0.000001
		and F_r_ot.length_squared() > 0.000001
	):
		# DEBUG: Check to see if wall repulsion is larger or smaller than agent repulsions
		print(
			parent.name,
			" | Wall: ", F_r_wa,
			" | Agent: ", lambda * F_r_ot,
			" | Total: ", F_r_wa + F_r_ob + lambda * F_r_ot
		)
	
	# Eq. (10)
	return F_r_ob + (lambda * F_r_ot) # this is fine
	#return F_r_wa + F_r_ob + (lambda * F_r_ot)
	

# FIXME: this does not work sometimes; im seeing agents pushing *into* a wall they're right next to.
func calculate_wall_repulsion():
	F_r_wa = Vector2.ZERO
	return
	
	# Key: wall normal (n_w), Value: wall distance (d_wi)
	var wall_hits: Dictionary = {}
	
	# Keep one closest hit per wall normal. So one ray per 1 wall face. In a corner, activate 2 rays, etc.
	for child in wall_repulsion_rays.get_children():
		var ray = child as RayCast2D
		if ray == null:
			continue
			
		ray.force_raycast_update()
		
		if not ray.is_colliding():
			continue

		var wall_collision_point: Vector2 = ray.get_collision_point()
		
		# n_w = wall normal
		var n_w: Vector2 = ray.get_collision_normal()
		
		# d_wi = shortest distance from the center of agent i to the wall w
		var d_wi: float = abs((parent.global_position - wall_collision_point).dot(n_w))
		if d_wi <= 0.0001:
			continue
			
		if not wall_hits.has(n_w) or d_wi < wall_hits[n_w]:
			wall_hits[n_w] = d_wi
	
	# Calculate wall repulsion from saved rays in wall_hits
	for wall_hit_normal: Vector2 in wall_hits:
		var wall_hit_distance: float = wall_hits[wall_hit_normal]
	
		# Overlap -> (r_i + ε_i - d_wi)) 
		var overlap: float = AGENT_RADIUS + personal_space - wall_hit_distance
		
		if overlap <= 0.0:
			continue
		
		# Eq. (11) -> (n_w * (r_i + ε_i - d_wi)) / d_wi
		var wall_repulsion = wall_hit_normal * overlap / wall_hit_distance
		
		F_r_wa += wall_repulsion

# TODO: Other object repulsion. get object actual radii?
func calculate_object_repulsion():
	F_r_ob = Vector2.ZERO

	for obstacle in overlapping_obstacles:
		if not is_instance_valid(obstacle):
			continue
		
		var p_i: Vector2 = parent.global_position
		var p_k: Vector2 = obstacle.global_position
		
		# p_i - p_k
		var away_vector: Vector2 = p_i - p_k
		
		# Distance between center of agent i and obstacle k
		var d_ki: float = (away_vector.length())
		if d_ki <= 0.0001:
			continue
		
		# Radii of agent
		var r_i: float = AGENT_RADIUS
		
		# Radii of obstacle k
		# TODO: get an actual one
		var r_k: float = AGENT_RADIUS
		
		# Calculating amount of overlap
		# r_i + ε_i + r_k - d_ki
		var overlap: float = r_i + personal_space + r_k - d_ki
		
		 # Only check if personal space overlap
		if overlap <= 0.0:
			continue
			
		# Calculating direction away from k
		# (p_i - p_k) / d_ji is the direction from k toward i
		var direction_away = away_vector / d_ki
		
		# Eq. (12)
		F_r_ob += direction_away * overlap

# Other agent repulsion
func calculate_other_agent_repulsion():
	F_r_ot = Vector2.ZERO
	agent_repulsion_forces.clear()
	
	for other_agent in overlapping_agents:
		if not is_instance_valid(other_agent):
			continue
			
		if other_agent == parent:
			continue
			
		# Fallen agents are calculated differently
		if other_agent.agent_state.is_fallen():
			continue
			
		var p_i: Vector2 = parent.global_position
		var p_j: Vector2 = other_agent.global_position
		
		# p_i - p_j
		var away_vector: Vector2 = p_i - p_j
		
		# Distance between center of agent i and j
		var d_ji: float = away_vector.length()
		if d_ji <= 0.0001:
			continue
		
		# Radii of agents
		var r_i: float = AGENT_RADIUS
		var r_j: float = AGENT_RADIUS
		
		# Calculating amount of overlap
		# r_i + ε_i + r_j - d_ji
		var overlap: float = r_i + personal_space + r_j - d_ji
		
		 # Only check if personal space overlap
		if overlap <= 0.0:
			continue
			
		# Calculating direction away from j
		# (p_i - p_j) / d_ji is the direction from j toward i
		var direction_away: Vector2 = away_vector / d_ji
		var repulsion_force: Vector2 = direction_away * overlap
		
		# Eq. (13)
		F_r_ot += repulsion_force
		
		# retain repulsion force
		agent_repulsion_forces.append(repulsion_force)
		
func _draw():
	# not technically an internal function as Node2D is not a canvasitem. we call this function from the parent instead.
	if parent:
		parent.draw_line(Vector2(0,0), F_r_wa*10, Color.LIME, 1.0)
		parent.draw_line(Vector2(0,0), F_r_ob*10, Color.GREEN, 1.0)
		parent.draw_line(Vector2(0,0), F_r_ot*10, Color.PURPLE, 1.0)
	
# TODO: Check if force from other agents is strong enough to make agents fall
func should_fall() -> bool:
	# minimal number of other agents
	if agent_repulsion_forces.size() < min_agent_repulsion_count:
		return false
		
	# Resulting pushing force is not strong enough
	if F_r_ot.length() < fall_force_threshold:
		return false
		
	# Resultant repulsion direction
	var resultant_direction: Vector2 = F_r_ot.normalized()
	# Number of other agents with aligned direction
	var aligned_count: int = 0
	
	for force in agent_repulsion_forces:
		if force.length() <= 0.0001:
			continue
		
		# repulsion force alignment with resultant direction
		var alignment = force.normalized().dot(resultant_direction)
		
		if alignment >= fall_alignment_threshold:
			aligned_count += 1
	
	# should fall if "majority" of forces approximately in the same direction
	# we define "majority" as more than half of the resulting forces
	return aligned_count > agent_repulsion_forces.size() * 0.5


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

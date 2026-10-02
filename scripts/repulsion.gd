extends Node2D

# Class to calculate the agent repulsion to the Wall, Other Obstacles and Other agents.
# Each component is calculated separately, but the global repulsion can be requested using get_total_repulsion()

# HiDAC Repulsion forces Eq. 10 - 13

const AGENT_RADIUS: float = 6.0

# Repuslion Forces
var F_r_wa: Vector2 = Vector2.ZERO
var F_r_ob: Vector2 = Vector2.ZERO
var F_r_ot: Vector2 = Vector2.ZERO

@onready var parent: CrowdAgent = get_parent()
@onready var repulsion_collision: CollisionShape2D = %CollisionShape2D
@onready var wall_ray_right: RayCast2D = %right

# Agent's Repulsion Area collision box radius currently set to the same size as Agent radius
# Agent's personal space (ε_i)
# ε_i
@export var personal_space: float = 4.0:
	set(value):
		personal_space = max(value, 0.0)

		if is_node_ready():
			_update_repulsion_area()


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

# Update ray length for right
func _update_wall_ray_length() -> void:
	var repulsion_range: float = AGENT_RADIUS + personal_space
	wall_ray_right.target_position = Vector2(repulsion_range, 0.0)
	
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
	if F_r_wa.length_squared() > 0 or F_r_ob.length_squared() > 0:
		lambda = 0.3
	
	# Eq. (10)
	return F_r_wa + F_r_ob + (lambda * F_r_ot)

# TODO: Wall repulsion
func calculate_wall_repulsion():
	F_r_wa = Vector2.ZERO

	if not wall_ray_right.is_colliding():
		return

	var wall_collision_point: Vector2 = wall_ray_right.get_collision_point()
	
	# n_w = wall normal
	var n_w: Vector2 = wall_ray_right.get_collision_normal()
	
	# d_wi = distance to wall collision point
	var d_wi: float = parent.global_position.distance_to(wall_collision_point)
		
	if d_wi <= 0.0001:
		return
	
	# Overlap -> (r_i + ε_i - d_wi)) 
	var overlap: float = AGENT_RADIUS + personal_space - d_wi
	
	if overlap <= 0.0:
		return
	
	# Eq. (11) -> (n_w * (r_i + ε_i - d_wi)) / d_wi
	F_r_wa = n_w * overlap / d_wi
	
	print(
		"WALL REPULSION",
		" | distance=", d_wi,
		" | normal=", n_w,
		" | overlap=", overlap,
		" | F_r_wa=", F_r_wa
	)

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
		var r_d: float = AGENT_RADIUS
		
		# Calculating amount of overlap
		# r_i + ε_i + r_d - d_ki
		var overlap: float = r_i + personal_space + r_d - d_ki
		
		 # Only check if personal space overlap
		if overlap <= 0.0:
			continue
			
		# Calculating direction away from k
		# (p_i - p_k) / d_ji is the direction from k toward i
		# var direction_away = away_vector / d_ki_m
		var direction_away = away_vector.normalized()
		
		# Eq. (12)
		F_r_ob += direction_away * overlap
	return

# Other agent repulsion
func calculate_other_agent_repulsion():
	F_r_ot = Vector2.ZERO
	for other_agent in overlapping_agents:
		if not is_instance_valid(other_agent):
			continue
			
		if other_agent == parent:
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
		# var direction_away = away_vector / d_ji_m
		var direction_away = away_vector.normalized()
		
		# Eq. (13)
		F_r_ot += direction_away * overlap
		
func _draw():
	# not technically an internal function as Node2D is not a canvasitem. we call this function from the parent instead.
	if parent:
		parent.draw_line(Vector2(0,0), F_r_wa*10, Color.REBECCA_PURPLE, 1.0)
		parent.draw_line(Vector2(0,0), F_r_ob*10, Color.BLUE_VIOLET, 1.0)
		parent.draw_line(Vector2(0,0), F_r_ob*10, Color.WEB_PURPLE, 1.0)
	
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

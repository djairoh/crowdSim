extends Node

# Class to calculate forces acting on an agent.
# Each component is calculated separately, but the global direction of force can be requested using get_total_forces()

# Obtained given an agent diameter represents 0.5m in real life.
# Given agent diameter = 12 pixels
# 12 / 0.5 = 24 
const PIXELS_PER_METER: float = 24

# Global force weights. Paper includes these weights but does not provide the value.
const W_AT: float = 1.0
const W_WA: float = 1.5
const W_OB: float = 0.2
const W_OT: float = 0.2

# forces
var F_wa: Vector2 = Vector2.ZERO
var F_ob: Vector2 = Vector2.ZERO
var F_ot: Vector2 = Vector2.ZERO
var F_at: Vector2 = Vector2.ZERO

# Rectangle of influence forward vision
@onready var forward_vision_collision: CollisionShape2D = %ForwardVisionCollisionShape2D

@onready var parent: CrowdAgent = get_parent()

# particulars
@onready var wall_left = $WallCast/left
@onready var wall_front = $WallCast/front
@onready var wall_right = $WallCast/right
@onready var f_at_nav = $AttractionNavigation

# track obstacles in recofinfluence
var visible_obstacles: Dictionary = {}
var visible_agents: Dictionary = {}

func pixels_to_meters(pixels: float) -> float:
	return pixels / PIXELS_PER_METER

func meters_to_pixels(meters: float) -> float:
	return meters * PIXELS_PER_METER

func is_inside_influence_rectangle(other_agent: Node2D) -> bool:
	var shape :RectangleShape2D = forward_vision_collision.shape as RectangleShape2D

	if shape == null:
		return false

	var local_position : Vector2 = forward_vision_collision.to_local(
		other_agent.global_position
	)

	var half_size : Vector2 = shape.size * 0.5

	return (
		abs(local_position.x) <= half_size.x
		and abs(local_position.y) <= half_size.y
	)

func get_desired_direction() -> Vector2:
	return 	parent.global_transform.origin.direction_to(f_at_nav.get_next_path_position())

func request_path(goal: Vector2) -> bool:
	f_at_nav.target_position = goal
	return f_at_nav.is_target_reachable()
	
func set_selected(val: bool):
	f_at_nav.debug_use_custom = val


func _get_force_from_raycast(ray: RayCast2D) -> Vector2:
	# REMBER: the original paper uses a double cross product to calculate avoidance direction. 
	# We instead rotate by -90 degrees perpendicular to the normal, which is equivalent in 2D
	# except when the two vectors are opposites, for which the dot product is 0.
	ray.force_raycast_update()
	if ray.is_colliding():
		var n = ray.get_collision_normal()
		var d = (ray.get_collision_point() - parent.global_position).length()
		var ndot = n.dot(parent.velocity)
		if not ndot:
			# v and n are opposites, so the dot product is zero.
			# That's fine, as in this case we want to move in the direction of n (away from the wall)
			return n * 1/d
		return Vector2(parent.velocity.x - ndot * n.x, parent.velocity.y - ndot * n.y) * 1/d
	return Vector2.ZERO

func calculate_wall_avoidance():
	# Calculate the avoidance force of the walls using 3 Raycasts.
	# FIXME: im seeing some weird behaviours when the wall is parallel to the agent. not sure how to fix that though
	F_wa  = _get_force_from_raycast(wall_left)
	F_wa += _get_force_from_raycast(wall_front)
	F_wa += _get_force_from_raycast(wall_right)
	F_wa = F_wa.normalized()
	# TODO: the individual components should be modulated by a weight factor w_wa_i. 
	# The paper does not specify how these are calculated ://
	
func calculate_object_avoidance():
	F_ob = Vector2.ZERO
	
	var v_i: Vector2 = parent.desired_velocity
	
	if v_i.length_squared() < 0.0001:
		return
		
	for obstacle in visible_obstacles:
		
		if not is_instance_valid(obstacle):
			continue
			
		# Check the actual rectangle.
		if not is_inside_influence_rectangle(obstacle):
			continue
		
		# Vector of current agent to obstacle
		var d_ki: Vector2 =  obstacle.global_position - parent.global_position
		
		if d_ki.length_squared() < 0.0001:
			continue
	
		# Eq. (4)
		# Using vector triple product identity
		var tangential_component: Vector2 = v_i * d_ki.length_squared() - d_ki * v_i.dot(d_ki)
		
		F_ob += tangential_component.normalized()
	
func calculate_other_agents_avoidance():	
	# Reset force
	F_ot = Vector2.ZERO
	
	var shape = forward_vision_collision.shape as RectangleShape2D
	if shape == null:
		push_error("Shape must be RectangleShape2D")
		return

	# Density of the crowd D_i: Agent perceived at any given time
	var D_i: float = pixels_to_meters(shape.size.x)
	
	var v_i: Vector2 = parent.desired_velocity
	
	if v_i.length_squared() < 0.0001:
		return
	
	for other_agent in visible_agents:
		
		if not is_instance_valid(other_agent):
			continue
			
		# Check the actual rectangle.
		if not is_inside_influence_rectangle(other_agent):
			continue
		
		# Vector of current agent to other agent
		var d_ji: Vector2 =  other_agent.global_position - parent.global_position
		
		if d_ji.length_squared() < 0.0001:
			continue
		
		var v_j: Vector2 = other_agent.desired_velocity
		
		# Actual istance between i and j in meters
		var distance: float = pixels_to_meters(d_ji.length())
		
		# Eq. (6)
		# Using vector triple product identity
		# (d_ji × v_i) × d_ji = v_i(d_ji⋅d_ji)−d_ji(v_i⋅d_ji)
		var tangential_component: Vector2 = v_i * d_ji.length_squared() - d_ji * v_i.dot(d_ji)
		
		# Tangential force (t_j) applied - make a curve in trajectory to avoid collision
		# tangential_component / |tangential_component|
		var t_j: Vector2
		
		if tangential_component.length_squared() <= 0.0001:
			t_j = get_right_vector(v_i)
		else:
			t_j = tangential_component.normalized()

		# Eq. (9)
		# Weight due to difference in velocity vectors. 
		# Distinguish whether agent j is moving in the same direction as agent i or against it.
		var w_o_i: float
		
		if (v_i.dot(v_j) > 0):
			w_o_i = 1.2
		else:
			w_o_i = 2.4
		
		# Eq. (8)
		# Weight due to distance between agents, increase as distance between two agents become 
		# smaller agent i trajectory will change more abrubtly as distance to j decrease
		var w_d_i: float = pow(distance - D_i, 2.0)
		
		# Eq. (7)
		F_ot += t_j * w_d_i * w_o_i

	
func get_right_vector(direction: Vector2) -> Vector2:
	var forward :Vector2 = direction.normalized()
	return Vector2(-forward.y, forward.x)
	

func calculate_attraction():
	# base navigation
	F_at = parent.desired_velocity.normalized()

func _update_forces():
	# update all forces. makes sure we're on the same page (will be useful if we later decide we don't want to update all forces every frame)
	calculate_attraction()
	calculate_wall_avoidance()
	calculate_object_avoidance()
	calculate_other_agents_avoidance()

func get_total_force(update: bool = false) -> Vector2:
	if update:
		_update_forces()
	# FIXME: does not apply weights as in the paper.
	return (F_at*W_AT + F_wa*W_WA + F_ot*W_OT + F_ob*W_OB).normalized()

func _draw():
	# not technically an internal function as Node2D is not a canvasitem. we call this function from the parent instead.
	if parent:
		parent.draw_line(Vector2(0,0), F_wa*W_WA*10, Color.GOLDENROD, 1.0)
		parent.draw_line(Vector2(0,0), F_at*W_AT*10, Color.SIENNA, 1.0)
		parent.draw_line(Vector2(0,0), F_ob*W_OB*10, Color.ORCHID, 1.0)
		parent.draw_line(Vector2(0,0), F_ot*W_OT*10, Color.TOMATO, 1.0)


func _on_rec_of_influence_body_entered(body: Node2D) -> void:
	if body.is_in_group("agent"):
		visible_agents.get_or_add(body, null)
	elif body.is_in_group("obstacle"):
		visible_obstacles.get_or_add(body, null)


func _on_rec_of_influence_body_exited(body: Node2D) -> void:
	if body.is_in_group("agent"):
		visible_agents.erase(body)
	elif body.is_in_group("obstacle"):
		visible_obstacles.erase(body)

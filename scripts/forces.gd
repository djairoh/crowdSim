extends Node

# Class to calculate forces acting on an agent.
# Each component is calculated separately, but the global direction of force can be requested using get_total_forces()

# forces
var F_wa: Vector2 = Vector2.ZERO
var F_ob: Vector2 = Vector2.ZERO
var F_ot: Vector2 = Vector2.ZERO
var F_at: Vector2 = Vector2.ZERO

# rectangle of influence
#@onready var collision_polygon_2d: CollisionPolygon2D = %CollisionPolygon2D
#func get_vision_length() -> float:
	#var polygon: PackedVector2Array = collision_polygon_2d.polygon
#
	#if polygon.is_empty():
		#return 0.0
	## based on manual inspection.
	#return 72
@onready var parent: CrowdAgent = get_parent()

# particulars
@onready var wall_left = $WallCast/left
@onready var wall_front = $WallCast/front
@onready var wall_right = $WallCast/right
@onready var f_at_nav = $AttractionNavigation

# track obstacles in recofinfluence
var visible_obstacles: Dictionary = {}
var visible_agents: Dictionary = {}


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
	print("calculating object avoidance...")
	
	# avoid visible_obstacles
	
func calculate_other_agents_avoidance():
	print("calculating other agent avoidance")
	
	# Reset force
	F_ot = Vector2.ZERO
	
	# Density of the crowd D_i
	# Agent perceived at any given time
	# If crowd is dispersed, people look for avoidance from far away and keep 
	# preferences on right hand side of space (D_i = 3m)
	# If crowd is dense, right preference is not obvious and biderectional flow
	# emerge. TODO: How to get perceived density -> Length of rectangle of influence?
	var D_i: float = 1.5
	
	for other_agent in visible_agents:
		
		if not is_instance_valid(other_agent):
			# TODO: Handle invalid instance?
			print("Invalid agent instance")
			continue
		
		# Vector of current agent to other agent
		var d_ji: Vector2 =  other_agent.global_position - parent.global_position
		var v_i: Vector2 = parent.velocity
		var v_j: Vector2 = other_agent.velocity
		
		print("d_ji: " + str(d_ji))
		
		
		# Distance to other agent
		var distance: float = d_ji.length()

		if distance <= 0.001:
			continue
		
		# Using vector triple product identity
		# (d_ji × v_i) × d_ji = v_i(d_ji⋅d_ji)−d_ji(v_i⋅d_ji)
		
		# (d_ji⋅d_ji) equals to d_ji.length_squared()
		var tangential_component: Vector2 = v_i * d_ji.length_squared() - d_ji * v_i.dot(d_ji)
		
		if tangential_component.length_squared() <= 0.001:
			continue
		
		# Tangential force
		# Tangential force (t_j) applied - make a curve in trajectory to avoid collisiom
		# tangential_component / |tangential_component|
		var t_j: Vector2 = tangential_component.normalized()
		print("t_j: " + str(t_j))
		
		
		# Direction of other agents relative to agent i desired velocity vector (vi)
		# Weight due to difference in velocity vectors. Distinguish whether agent j
		# is moving in the same direction as agent i or against it.
		# Magnitude will be higher to avoid counter flow
		var w_o_i: float = 1.2
		
		if (v_i.dot(v_j) > 0):
			w_o_i = 1.2
		else:
			w_o_i = 2.4
		
		print("w_o_i: " + str(w_o_i))
		
		# Ignore agents outside of rectangle of influence
		if distance >= D_i:
			continue

		# Weight due to distance between agents, increase as distance between two agents become smaller
		# agent i trajectory will change more abrubtly as distance to j decrease
		var w_d_i: float = pow(distance - D_i, 2.0)
		print("w_d_i: " + str(w_d_i))
		
		F_ot += t_j * w_d_i * w_o_i
		
	print("F_ot: " + str(F_ot))
	

func calculate_attraction():
	# base navigation
	F_at = parent.global_transform.origin.direction_to(f_at_nav.get_next_path_position())

func _update_forces():
	# update all forces. makes sure we're on the same page (will be useful if we later decide we don't want to update all forces every frame)
	calculate_wall_avoidance()
	calculate_other_agents_avoidance()
	calculate_attraction()

func get_total_force(update: bool = false) -> Vector2:
	if update:
		_update_forces()
	# FIXME: does not apply weights as in the paper.
	return (F_at + F_wa*1.5 + F_ot + F_ob).normalized()

func _draw():
	# not technically an internal function as Node2D is not a canvasitem. we call this function from the parent instead.
	if parent:
		parent.draw_line(Vector2(0,0), F_wa*10, Color.GOLDENROD, 1.0)
		parent.draw_line(Vector2(0,0), F_at*10, Color.SIENNA, 1.0)
		parent.draw_line(Vector2(0,0), F_ob*10, Color.ORCHID, 1.0)
		parent.draw_line(Vector2(0,0), F_ot*10, Color.TOMATO, 1.0)


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

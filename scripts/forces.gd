extends Node

# Class to calculate forces acting on an agent.
# Each component is calculated separately, but the global direction of force can be requested using get_total_forces()

# forces
var F_wa: Vector2 = Vector2.ZERO
var F_ob: Vector2 = Vector2.ZERO
var F_ot: Vector2 = Vector2.ZERO
var F_at: Vector2 = Vector2.ZERO

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

func calculate_attraction():
	# base navigation
	F_at = parent.global_transform.origin.direction_to(f_at_nav.get_next_path_position())

func _update_forces():
	# update all forces. makes sure we're on the same page (will be useful if we later decide we don't want to update all forces every frame)
	calculate_wall_avoidance()
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

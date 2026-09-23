extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd

var social_forces: SocialForces


var F_wa: Vector2

@onready var navigation_agent = $NavigationAgent2D
@onready var collision_shape = $CollisionShape2D
@onready var idle_timer = $MoveIdleTimer
@onready var wall_cast = $ShapeCastWalls
@export var movement_speed: float = 32.0
@export var max_movement: float = 10
# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager
var start_position: Vector2
var goal: Vector2
var visible_obstacles: Dictionary = {}
var visible_agents: Dictionary = {}
var desired_rotation: float = self.rotation

func _ready():
	social_forces = SocialForces.new()
	start_position = global_position


func set_crowd_manager(crowd_manager: CrowdManager):
	self.crowd_manager = crowd_manager


func request_path(goal: Vector2) -> bool:
	#print("agent working towards", goal)
	self.goal = goal
	navigation_agent.target_position = goal
	return navigation_agent.is_target_reachable()

func _process(delta: float) -> void:
	if self.rotation != self.desired_rotation:
		self.rotation = lerp_angle(self.rotation, self.desired_rotation, clampf(4*delta, 0, 1))

func _physics_process(delta):
	if navigation_agent.is_navigation_finished():
		if navigation_agent.is_target_reached():
			self.queue_free()
		# TODO: select a new goal? or at least consider what we want to happen once a goal is reached
		return

	# base navigation
	var current_agent_position: Vector2 = global_transform.origin
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var F_at = current_agent_position.direction_to(next_path_position)

	# wall collision
	wall_cast.force_shapecast_update()
	F_wa = Vector2.ZERO
	if wall_cast.is_colliding():
		for i in wall_cast.get_collision_count():
			print("collision ", i)
			var n = wall_cast.get_collision_normal(i)
			var d = (wall_cast.get_collision_point(i) - global_transform.origin).length()
			F_wa += Vector2(velocity.x - n.dot(velocity) * n.x, velocity.y - n.dot(velocity) * n.y ) * d
			# REMBER: the original paper uses a double cross product to calculate avoidance direction. We  simply rotate by -90 degrees perpendicular to the normal 
	F_wa = F_wa.normalized()
	F_wa = F_wa * movement_speed/2
	# FIXME: scaling on F_wa is definitely wonky.. need a distance factor to multiply d with, to make it align with the forces for F_at
	# TODO: implement rest of social forces in here as well

	velocity = F_at*movement_speed/2 + F_wa
	

	#velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	# TODO: include social forces
	self.desired_rotation = atan2(velocity.y, velocity.x)
	move_and_slide()
	queue_redraw()
	return

	## social forces
	#var forces = social_forces.calculate_total_force(
		#global_position,
		#current_path_point,
		#nearby_agents,
		#nearby_obstacles,
		#movement_speed
	#)
#
	#var movement_delta = movement_speed * delta
	#var new_velocity = forces * 0.01 * movement_delta
	## var new_velocity = global_transform.origin.direction_to(current_path_point) * movement_delta
	#global_transform.origin = global_transform.origin.move_toward(global_transform.origin + new_velocity, movement_delta)

func _draw():
	draw_line(Vector2(0,0), F_wa, Color.BLUE, 2.0)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			SelectionManager.select(self)


func set_selected(val: bool) -> void:
	$NavigationAgent2D.debug_use_custom = val


func _on_move_idle_timer_timeout() -> void:
	var distance_moved = start_position.distance_to(global_position)
	if distance_moved < max_movement:
		request_path(goal);
	start_position = global_position


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

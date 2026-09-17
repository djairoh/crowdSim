extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd
# TODO: for debugging, i want to be able to click on an agent and have its path change colour. add that functionality.

var social_forces: SocialForces

@onready var navigation_agent = $NavigationAgent2D
@onready var collision_shape = $CollisionShape2D
var movement_speed: float = 4.0
# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager

func _ready():
	social_forces = SocialForces.new()

	# TODO: placeholder values; tweak these
	navigation_agent.path_desired_distance = 5.0
	navigation_agent.target_desired_distance = 5.0
	navigation_agent.debug_enabled = true


func set_crowd_manager(crowd_manager: CrowdManager):
	self.crowd_manager = crowd_manager
	
func request_path(goal: Vector2):
	print("agent working towards", goal)
	# current_path = NavigationServer2D.map_get_path(map, global_transform.origin, goal, true)

	navigation_agent.target_position = goal
	# FIXME (high priority): this is using the wrong map, or its unintialized, or **something**
	# as in, we see no paths ://

	#if not current_path.is_empty():
		#current_path_index = 0
		#current_path_point = current_path[0]




func _physics_process(delta):
	if navigation_agent.is_navigation_finished():
		# TODO: select a new goal? or at least condier what we want to happen once a goal is reached 
		return

	var current_agent_position: Vector2 = global_position
	var next_path_position: Vector2 = navigation_agent.get_next_path_position()

	velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	# TODO: include social forces
	move_and_slide()

	#queue_redraw()
	return


	#if current_path.is_empty():
		#velocity = Vector2.ZERO
		#return
#
	## check if we've reached our interim target yet
	#if global_transform.origin.distance_to(current_path_point) < 10.0:
		#current_path_index += 1
		#if current_path_index >= current_path.size():
			#current_path = []
			#current_path_index = 0
			#current_path_point = global_transform.origin
			#return
#
	#current_path_point = current_path[current_path_index]
	## get nearby agents from crowd manager
	#var nearby_agents = crowd_manager.get_nearby_agents(global_position, 100.0, self) if crowd_manager else []
	## FIXME: this is deprecated now, figure out something to get our custom obstacles to play nice with godots inbuilt collision
	#var nearby_obstacles = crowd_manager.get_nearby_obstacles(global_position, 100.0) if crowd_manager else []
#
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

	#queue_redraw()



#func _draw():
	#if current_path.size() > 0:
		## draw path
		#for i in range(current_path.size() - 1):
			#draw_line(current_path[i] - global_position, current_path[i + 1] - global_position, Color.YELLOW, 1.0)
#
		## draw progress on path
		#if current_path_index < current_path.size():
			#draw_circle(current_path[current_path_index] - global_position, 5, Color.RED)
#
	## draw forces
	## TODO: make these draw individual forces instead of the total velocity
	#draw_line(Vector2(0,0), velocity.normalized() * 20, Color.GREEN)

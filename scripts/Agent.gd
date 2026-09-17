extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd
# TODO: for debugging, i want to be able to click on an agent and have its path change colour. add that functionality.

# bluhhh many variables here; TODO: check we actually need all that.
var social_forces: SocialForces
var current_path: PackedVector2Array
var current_path_index: int = 0
var current_path_point: Vector2

@onready var collision_shape = $CollisionShape2D
# THOUGHT: could prolly extract these to a resource
var movement_speed: float = 4.0
var recalc_distance: float = 50.0
var agent_radius: float = 10.0
# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager
var map: RID

func _ready():
	social_forces = SocialForces.new()


func set_crowd_manager(crowd_manager: CrowdManager):
	self.crowd_manager = crowd_manager
	
func set_map(map: RID):
	self.map = map


func request_path(goal: Vector2):
	print("agent working towards", goal)
	current_path = NavigationServer2D.map_get_path(map, global_transform.origin, goal, true)
	# FIXME (high priority): this is using the wrong map, or its unintialized, or **something**
	# as in, we see no paths ://

	if not current_path.is_empty():
		current_path_index = 0
		current_path_point = current_path[0]




func _physics_process(delta):
	if current_path.is_empty():
		velocity = Vector2.ZERO
		return

	# check if we've reached our interim target yet
	if global_transform.origin.distance_to(current_path_point) < 10.0:
		current_path_index += 1
		if current_path_index >= current_path.size():
			current_path = []
			current_path_index = 0
			current_path_point = global_transform.origin
			return

	current_path_point = current_path[current_path_index]
	# get nearby agents from crowd manager
	var nearby_agents = crowd_manager.get_nearby_agents(global_position, 100.0, self) if crowd_manager else []
	# FIXME: this is deprecated now, figure out something to get our custom obstacles to play nice with godots inbuilt collision
	var nearby_obstacles = crowd_manager.get_nearby_obstacles(global_position, 100.0) if crowd_manager else []

	# social forces
	var forces = social_forces.calculate_total_force(
		global_position,
		current_path_point,
		nearby_agents,
		nearby_obstacles,
		movement_speed
	)

	var movement_delta = movement_speed * delta
	var new_velocity = forces * 0.01 * movement_delta
	# var new_velocity = global_transform.origin.direction_to(current_path_point) * movement_delta
	global_transform.origin = global_transform.origin.move_toward(global_transform.origin + new_velocity, movement_delta)

	queue_redraw()



func _draw():
	if current_path.size() > 0:
		# draw path
		for i in range(current_path.size() - 1):
			draw_line(current_path[i] - global_position, current_path[i + 1] - global_position, Color.YELLOW, 1.0)

		# draw progress on path
		if current_path_index < current_path.size():
			draw_circle(current_path[current_path_index] - global_position, 5, Color.RED)

	# draw forces
	# TODO: make these draw individual forces instead of the total velocity
	draw_line(Vector2(0,0), velocity.normalized() * 20, Color.GREEN)

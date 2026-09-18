extends Node2D
class_name CrowdManager

# basically the driver code
# manages individual agents, the level, allat

var agents: Array[CrowdAgent] = []
var obstacles: Array[Vector2] = [] # This is deprecated as of rn. need to figure out a way to make our custom pathing play nice with inbuilt collision detection 

@onready var lvl = $level
@onready var nav_reg = $level/NavigationRegion2D

func _ready():
	var viewport_size = get_viewport_rect().size


	# test agents. TODO: better logic for agent spawning/despawning. discuss w Raisa how we want to tackle this.
	for i in range(10):
		var agent = preload("res://scenes/crowd_agent.tscn").instantiate()
		agent.global_position = lvl.get_random_spawn()
		agent.set_crowd_manager(self)
		add_child(agent)
		agents.append(agent)

	_send_agents_to_random_goals()

func _send_agents_to_random_goals():
	for agent in agents:
		agent.request_path(lvl.get_random_goal())

# get all agents within range of given point
# these are very back-of-the-hand. the actual hidac system uses a shape for viewing, which would play nicely with godots inbuilt collision stuff.
# TODO: refactor to use godots inbuilt collisions.
func get_nearby_agents(position: Vector2, radius: float, exclude_agent: CrowdAgent) -> Array[Vector2]:
	var nearby: Array[Vector2] = []

	for agent in agents:
		if agent == exclude_agent:
			continue
		
		var distance = position.distance_to(agent.global_position)
		if distance < radius:
			nearby.append(agent.global_position)

	return nearby


# get all obstacles within range of given point
# FIXME: this is nonfunctional as of rn
func get_nearby_obstacles(position: Vector2, radius: float) -> Array[Vector2]:
	var nearby: Array[Vector2] = []

	# FIXME: deprecated obstacles array; use tilemap + tiles with collision instead.
	for obstacle_pos in obstacles:
		var distance = position.distance_to(obstacle_pos)
		if distance < radius:
			nearby.append(obstacle_pos)
	return nearby
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.deselect()

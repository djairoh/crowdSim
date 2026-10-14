extends Node2D
class_name CrowdManager

# basically the driver code
# manages individual agents, the level, allat

@onready var lvl = $level
@onready var nav_reg = $level/NavigationRegion2D

# Panic agent ratio
@export_range(0.0, 1.0)
var panic_ratio: float = 0.2

@export_range(0.0, 1.0)
var impatient_ratio: float = 0.2

@export var max_agents: int = 200
var num_agents: int = 0
var agents: Array

func _ready():
	pass


func _spawn_agent():
	var agent = preload("res://scenes/crowd_agent.tscn").instantiate()
	call_deferred("_initialize_agent", agent)
	agents.append(agent)
	num_agents += 1
	agent.despawned.connect(_on_agent_despawned)
	add_child(agent)

func _initialize_agent(agent: CrowdAgent):
	agent.set_crowd_manager(self)
	agent.global_position = lvl.get_random_spawn()
	
	# Set panic agents
	if randf() < impatient_ratio:
		agent.agent_state.set_impatient()
	elif randf() < panic_ratio:
		agent.agent_state.set_panic()
	else:
		agent.agent_state.set_normal()
		
	agent.request_path(lvl.get_random_goal())
	# FIXME: agent unreachable target logic
	#while agent.request_path(lvl.get_random_goal()) == false:
		#print("target unreachable. selecting new one")
		#agent.global_position = lvl.get_random_spawn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.deselect()

func _on_agent_despawned(agent: CrowdAgent):
	# TODO: logic here for spawning new agents; instead of on timer.
	agents.erase(agent)
	num_agents -= 1


func _on_agent_spawn_timer_timeout() -> void:
	if num_agents < max_agents:
		_spawn_agent()


func _on_door_toggle_timer_timeout() -> void:
	lvl.toggle_all_doors()
	nav_reg.bake_navigation_polygon()
	for a in agents:
		a.request_path(a.goal)

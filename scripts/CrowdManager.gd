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

func _ready():
	var agent = preload("res://scenes/crowd_agent.tscn").instantiate()
	call_deferred("_initialize_agent", agent)
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


func _on_agent_spawn_timer_timeout() -> void:
	var agent = preload("res://scenes/crowd_agent.tscn").instantiate()
	call_deferred("_initialize_agent", agent)
	add_child(agent)

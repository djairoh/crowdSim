extends Node2D
class_name CrowdManager

# basically the driver code
# manages individual agents, the level, allat

@onready var levelSelect: Node = $LevelSelect
@onready var cam: Camera2D = $Camera2D
var current_level: Node

# Panic agent ratio
@export_range(0.0, 1.0)
var panic_ratio: float = 0.1

@export_range(0.0, 1.0)
var impatient_ratio: float = 0.5

# TODO: move max_agents and both timers to the level instead, then connect here with custom signals.
@export var max_agents: int = 40
var num_agents: int = 0
var agents: Array
@export var debug_enabled: bool = false
var is_paused: bool = false

func _ready():
	show_level_selection()
	
func toggle_pause_simulation():
	is_paused = !is_paused
	for a in agents:
		a.set_pause(is_paused)
	$agent_spawn_timer.paused = is_paused
	$door_toggle_timer.paused = is_paused
		
func reset_simulation():
	for a in agents:
		a.queue_free()
	agents = []
	num_agents = 0
	
func start_simulation():
	$agent_spawn_timer.start()
	$door_toggle_timer.start()
	cam.reset()
	cam.set_input_enabled(true)
	
func stop_simulation():
	$agent_spawn_timer.stop()
	$door_toggle_timer.stop()
	
func show_level_selection():
	levelSelect.visible = true
	levelSelect.create_level_buttons(self)
	levelSelect.setCamera(cam)
	cam.set_input_enabled(false)
	
func load_level(lvl: String):
	if current_level:
		current_level.queue_free()
		
	var selected = $Levels.find_child(lvl, false)
	if selected:
		current_level = selected.create_instance()
		current_level.z_index = -1 # render behind agents
		levelSelect.visible = false
		start_simulation()

func unload_level():
	if current_level:
		current_level.queue_free()
		current_level = null
	show_level_selection()

func toggle_debug():
	debug_enabled = !debug_enabled
	for a in agents:
		a.set_debug(debug_enabled)

func _spawn_agent():
	var agent = preload("res://scenes/crowd_agent.tscn").instantiate()
	call_deferred("_initialize_agent", agent)
	agents.append(agent)
	num_agents += 1
	agent.despawned.connect(_on_agent_despawned)
	add_child(agent)

func _initialize_agent(agent: CrowdAgent):
	var sg = current_level.get_spawn_goal_pair()
	# check if the spawnpoint still contains an agent; if so, cancel this spawn
	for a in agents:
		if a.global_position.distance_to(sg[0]) < 10:
			agents.erase(agent)
			agent.queue_free()
			num_agents = max(0, num_agents-1)
			return

	agent.set_crowd_manager(self)
	agent.global_position = sg[0]
	agent.set_debug(debug_enabled)
	
	# Set panic agents
	if randf() < impatient_ratio:
		agent.agent_state.set_impatient()
	elif randf() < panic_ratio:
		agent.agent_state.set_panic()
	else:
		agent.agent_state.set_normal()
		
	agent.request_path(sg[1])

func _input(event):
	if event.is_action_pressed("toggleDebug"):
		toggle_debug()
	if event.is_action_pressed("togglePause"):
		toggle_pause_simulation()
	if event.is_action_pressed("resetSimulation"):
		reset_simulation()
	if event.is_action_pressed("newLevel"):
		stop_simulation()
		reset_simulation()
		unload_level()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		SelectionManager.deselect()


func _on_agent_despawned(agent: CrowdAgent):
	agents.erase(agent)
	num_agents = max(0, num_agents-1)


func _on_agent_spawn_timer_timeout() -> void:
	if num_agents < max_agents:
		_spawn_agent()


func _on_door_toggle_timer_timeout() -> void:
	if current_level:
		current_level.toggle_all_doors()
		current_level.bake_nav_reg()
		for a in agents:
			a.request_path(a.goal)

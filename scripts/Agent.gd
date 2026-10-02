extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd

@onready var forces = $Forces
@onready var repulsion = $Repulsion
@export var max_speed: float = 32.0
@export var acceleration: float = 10.0
@export var max_movement: float = 10

# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager
var start_position: Vector2
var goal: Vector2
var desired_rotation: float = self.rotation
var desired_velocity: Vector2 = Vector2.ZERO
var current_speed: float = 0.0

func _ready():
	start_position = global_position


func set_crowd_manager(crowd_manager: CrowdManager):
	self.crowd_manager = crowd_manager


func request_path(goal: Vector2) -> bool:
	self.goal = goal
	return forces.request_path(goal)

func _process(delta: float) -> void:
	if self.rotation != self.desired_rotation:
		self.rotation = lerp_angle(self.rotation, self.desired_rotation, clampf(4*delta, 0, 1))

func _physics_process(delta):
	self.desired_velocity = (
		forces.get_desired_direction()
		* max_speed
	)
	
	# Eq. (1) + Eq. (2)
	var f_to = forces.get_total_force(true)
	
	# Eq. (10)
	var r_i = repulsion.get_total_repulsion(true)
	
	# α represents whether the agent will move in this step in
	# its desired direction of movement or instead be pushed
	# by a repulsion force.
	var alpha_i: float = 1.0
	if r_i.length_squared() > 0.0001:
		alpha_i = 0.0
		
	# TODO: CHANGE beta_i to represent falling agents
	var beta_i: float = 0.0
	
	# Update v_i[n].
	# v_i[n] = min(v_i[n-1] + aT, v_i_MAX)
	current_speed = min(current_speed + acceleration * delta, max_speed)
	
	# Simplified Eq. (3), beta_i = 0
	# Paper uses equation to get desired position p_i[n+1]
	# But Godot move_and_slide requires velocity. 
	# Instead of desired position, we use the change in position (displacement) to get velocity
	#
	# So we modify this equation for displacement
	# p_i[n] = p_i[n-1] + alpha_i * v_i[n] * f_to * T + r_i
	# p_i[n] - p_i[n-1] = alpha_i * v_i[n] * f_to * T + r_i
	# displacement = alpha_i * v_i[n] * f_to * T + r_i
	var displacement: Vector2 = (
		alpha_i
		* current_speed
		* f_to
		* delta
		+ r_i
	)

	# DEPRECATED: position calculation is not implemented as it is in the paper.
	#velocity = f_to * max_speed
	
	# Position calculation adapted from the paper.
	velocity = displacement / delta
	
	# Only update rotation when moving
	if velocity.length_squared() > 0.0001:
		self.desired_rotation = atan2(velocity.y, velocity.x)
		
	move_and_slide()
	queue_redraw()
	
func _draw():
	forces._draw()
	repulsion._draw()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			SelectionManager.select(self)


func set_selected(val: bool) -> void:
	forces.set_selected(val)
	if val:
		modulate = Color.HOT_PINK
	else:
		modulate = Color.WHITE


func _on_move_idle_timer_timeout() -> void:
	var distance_moved = start_position.distance_to(global_position)
	if distance_moved < max_movement:
		request_path(goal);
	start_position = global_position


func _on_attraction_navigation_target_reached() -> void:
	# TODO: what do when goal is reached?
	self.queue_free()

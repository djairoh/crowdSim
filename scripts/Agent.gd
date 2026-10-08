extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd

# collision shapes for agents
@onready var standing_collision: CollisionShape2D = $CollisionShape2D
@onready var fallen_collision: CollisionShape2D = $FallenCollisionShape2D

@onready var forces = $Forces
@onready var repulsion = $Repulsion
@onready var rules = $Rules
@onready var agent_state: AgentState = $AgentState
@onready var behaviours: Behaviours = $Behaviours

@export var max_speed: float = 32.0
@export var panic_speed_multiplier: float = 1.4
@export var acceleration: float = 10.0
@export var max_movement: float = 10
@export var start_fallen: bool = false

# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager
var start_position: Vector2
var goal: Vector2
var desired_rotation: float = self.rotation
var desired_velocity: Vector2 = Vector2.ZERO
var current_speed: float = 0.0

func _ready():
	start_position = global_position
	
	if start_fallen:
		behaviours.falling.fall()

func set_crowd_manager(crowd_manager: CrowdManager):
	self.crowd_manager = crowd_manager


func request_path(goal: Vector2) -> bool:
	self.goal = goal
	return forces.request_path(goal)

func _process(delta: float) -> void:
	if self.rotation != self.desired_rotation:
		self.rotation = lerp_angle(self.rotation, self.desired_rotation, clampf(4*delta, 0, 1))

func _physics_process(delta):
	# Stop moving if agent falls.
	if agent_state.is_fallen():
		velocity = Vector2.ZERO
		return
	
	# Eq. (1) + Eq. (2)
	var f_to = forces.get_total_force(true)
	
	# Eq. (10)
	var r_i = repulsion.get_total_repulsion(true)
	
	# α represents whether the agent will move in this step in
	# its desired direction of movement or instead be pushed
	# by a repulsion force.
	var alpha_i: float = 1.0
	
	# Update stopping rule to prevent shaking agents
	rules.update_rules(delta)
	
	# Update agent state
	#agent_state.update(delta)
	
	# Update agent behaviours
	behaviours.update(delta)
	
	if r_i.length_squared() > 0.0001 or rules.stopping_rule or rules.waiting_rule:
		alpha_i = 0.0
		
	# Fallen agents forces
	var F_fa: Vector2 = forces.get_falling_agent_force()
		
	# TODO: CHANGE beta_i to represent falling agents
	var beta_i: float = 0.0
	
	if F_fa.length_squared() > 0.0001:
		beta_i = 0.5
	
	# movement_direction = normal desired direction + fallen agent avoidance
	# movement_direction = ((1-βi[n]) * f_to_i[n]) + (βi[n] * F_fa_i[n])
	var movement_direction: Vector2 = (
		(1.0 - beta_i) * f_to
		+ beta_i * F_fa
	)
	
	if movement_direction.length_squared() > 0.0001:
		movement_direction = movement_direction.normalized()
		
	var target_max_speed: float = max_speed
	
	# Increase movement speed when panic
	if agent_state.is_panic():
		target_max_speed *= panic_speed_multiplier
		
	self.desired_velocity = forces.get_desired_direction() * target_max_speed

	# Update v_i[n].
	# v_i[n] = min(v_i[n-1] + aT, v_i_MAX)
	current_speed = min(current_speed + acceleration * delta, target_max_speed)
	
	# Eq. (3)
	# Paper uses equation to get desired position p_i[n+1]
	# But Godot move_and_slide requires velocity. 
	# Instead of desired position, we use the change in position (displacement) to get velocity
	#
	# So we modify this equation for displacement
	# p_i[n] = p_i[n-1] + alpha_i * v_i[n] * movement_direction * T + r_i
	# p_i[n] - p_i[n-1] = alpha_i * v_i[n] * movement_direction * T + r_i
	# displacement = alpha_i * v_i[n] * movement_direction * T + r_i
	var displacement: Vector2 = (
		alpha_i
		* current_speed
		* movement_direction
		* delta
		+ r_i
	)

	# DEPRECATED: position calculation is not implemented as it is in the paper.
	#velocity = f_to * max_speed
	
	# Position calculation adapted from the paper.
	velocity = displacement / delta
	
	# Only update rotation when moving
	if velocity.length_squared() > 0.0001:
		# Rotate agent to desired direction
		self.desired_rotation = atan2(self.desired_velocity.y, self.desired_velocity.x)
		
		
	#if movement_direction.length_squared() > 0.0001:
		#self.desired_rotation = atan2(
			#movement_direction.y,
			#movement_direction.x
		#)
		#
	move_and_slide()
	queue_redraw()
	
func _draw():
	if agent_state.is_fallen():
		var fallen_color: Color

		if behaviours.falling.is_being_stepped_on():
			fallen_color = Color(1.0, 0.4, 0.0, 0.7) # orange, stepped on
		else:
			fallen_color = Color(0.5, 0.0, 0.0, 0.4) # transparent dark red

		draw_rect(
			Rect2(-14.0, -6.0, 28.0, 12.0),
			fallen_color,
			true
		)
		
	forces._draw()
	repulsion._draw()
		
	## Show panic agents
	#if agent_state.is_panic():
		#draw_circle(Vector2.ZERO, 6.0, Color.ORANGE_RED, true)

	
	if rules.stopping_rule:
		draw_circle(Vector2.ZERO, 8.0, Color.RED, false, 2.0)
		draw_line(Vector2.ZERO, repulsion.F_r_ot * 20.0, Color.RED, 2.0)
		
	if rules.waiting_rule:
		draw_circle(Vector2.ZERO, 8.0, Color.GREEN, false, 2.0)
		draw_line(Vector2.ZERO, repulsion.F_r_ot * 20.0, Color.GREEN, 2.0)
	
	var r_i = repulsion.get_total_repulsion(false)
	if r_i.length_squared() > 0.0001:
		draw_circle(Vector2(0,0), 8.0, Color.BLUE_VIOLET, false, 2.0)
		draw_line(Vector2(0,0), repulsion.F_r_ot * 20.0, Color.BLUE_VIOLET, 2.0)

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

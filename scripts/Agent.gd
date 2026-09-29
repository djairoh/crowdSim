extends CharacterBody2D
class_name CrowdAgent

# this class models an individual in a crowd

@onready var forces = $Forces
@export var movement_speed: float = 32.0
@export var max_movement: float = 10

# refing to parent nodes like this is bad practice, but who caresssss 
var crowd_manager: CrowdManager
var start_position: Vector2
var goal: Vector2
var desired_rotation: float = self.rotation
var desired_velocity: Vector2 = Vector2.ZERO

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
		* movement_speed
	)

	var f_to = forces.get_total_force(true)

	# TODO: position calculation is not implemented as it is in the paper.
	velocity = f_to * movement_speed
	self.desired_rotation = atan2(velocity.y, velocity.x)
	move_and_slide()
	queue_redraw()
	
func _draw():
	forces._draw()

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

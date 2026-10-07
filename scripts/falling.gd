extends Node2D
class_name Falling

@onready var parent: CrowdAgent = get_parent().get_parent()
@onready var fallen_body_area: Area2D = $FallingBodyArea
@onready var fallen_collision: CollisionShape2D = $FallingBodyArea/CollisionShape2D

var agents_stepping_on: Array[CrowdAgent] = []

func _ready() -> void:
	fallen_collision.disabled = true


func fall() -> void:
	if parent.agent_state.is_fallen():
		return

	parent.agent_state.set_fallen()

	parent.velocity = Vector2.ZERO
	parent.current_speed = 0.0

	fallen_collision.set_deferred("disabled", false)

	parent.queue_redraw()


func is_being_stepped_on() -> bool:
	if not parent.agent_state.is_fallen():
		return false

	for body in fallen_body_area.get_overlapping_bodies():
		if body == parent:
			continue

		if body is CrowdAgent and not body.agent_state.is_fallen():
			return true

	return false
	
func _on_falling_body_area_body_entered(body: Node2D) -> void:
	if not parent.agent_state.is_fallen():
		return

	if body == parent:
		return

	if body is CrowdAgent:
		agents_stepping_on.append(body)
		parent.queue_redraw()


func _on_falling_body_area_body_exited(body: Node2D) -> void:
	if body is CrowdAgent:
		agents_stepping_on.erase(body)
		parent.queue_redraw()

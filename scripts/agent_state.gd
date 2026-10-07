extends Node2D

# This class handles the different types of agent states and remove coupling from 
# agent class trying to handle states
# TODO: Update sprite colors
class_name AgentState

@onready var sprite: Sprite2D = get_parent().get_node("Sprite2D")


enum states {
	NORMAL,
	PANIC,
	IMPATIENT
}

@export var current_state = states.NORMAL

# Set the states
func set_normal() -> void:
	current_state = states.NORMAL
	sprite.modulate = Color.LIGHT_BLUE
	
func set_panic() -> void:
	current_state = states.PANIC
	sprite.modulate = Color.RED

func set_impatient() -> void:
	current_state = states.IMPATIENT
	sprite.modulate = Color.YELLOW
	
# Check agent state
func is_normal() -> bool:
	return current_state == states.NORMAL

func is_panic() -> bool:
	return current_state == states.PANIC

func is_impatient() -> bool:
	return current_state == states.IMPATIENT

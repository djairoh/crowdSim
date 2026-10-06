extends Node2D

# This class handles the different types of agent states and remove coupling from 
# agent class trying to handle states
class_name AgentState

enum states {
	NORMAL,
	PANIC,
	IMPATIENT
}

@export var current_state = states.NORMAL

# Set the states
func set_normal() -> void:
	current_state = states.NORMAL

func set_panic() -> void:
	current_state = states.PANIC

func set_impatient() -> void:
	current_state = states.IMPATIENT
	
# Check agent state
func is_normal() -> bool:
	return current_state == states.NORMAL

func is_panic() -> bool:
	return current_state == states.PANIC

func is_impatient() -> bool:
	return current_state == states.IMPATIENT

extends Node

var selected: CrowdAgent = null

func select(agent: CrowdAgent) -> void:
	if selected == agent:
		return
		
	if selected != null:
		selected.set_selected(false)
		
	selected = agent
	selected.set_selected(true)

func deselect() -> void:
	if selected != null:
		selected.set_selected(false)
		selected = null

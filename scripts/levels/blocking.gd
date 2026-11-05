extends AbstractLevel

func _ready() -> void:
	super()
	_setup_goal_spawn_pairs()

func _setup_goal_spawn_pairs():
	print(spawns)
	print(goals)
	for s in self.spawns.size():
		spawn_goal_pairs.append([spawns[s], goals[s]])

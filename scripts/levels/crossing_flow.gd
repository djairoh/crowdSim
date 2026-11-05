extends AbstractLevel

func _ready() -> void:
	super()
	_setup_spawn_goal_pairs()

func _setup_spawn_goal_pairs():
	spawn_goal_pairs.append([spawns[0], goals[2]])
	spawn_goal_pairs.append([spawns[1], goals[3]])
	spawn_goal_pairs.append([spawns[2], goals[0]])
	spawn_goal_pairs.append([spawns[3], goals[1]])
	print(spawns)
	print(goals)
	print(spawn_goal_pairs)

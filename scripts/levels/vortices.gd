extends AbstractLevel

func _ready() -> void:
	super()
	_setup_goal_spawn_pairs()

func _setup_goal_spawn_pairs():
	print(spawns)
	print(goals)
	# neighbors
	spawn_goal_pairs.append([spawns[0], goals[2]])
	spawn_goal_pairs.append([spawns[1], goals[3]])
	spawn_goal_pairs.append([spawns[2], goals[0]])
	spawn_goal_pairs.append([spawns[3], goals[1]])
	# mirrors
	spawn_goal_pairs.append([spawns[0], goals[3]])
	spawn_goal_pairs.append([spawns[1], goals[1]])
	spawn_goal_pairs.append([spawns[2], goals[2]])
	spawn_goal_pairs.append([spawns[3], goals[0]])
	print(spawn_goal_pairs)

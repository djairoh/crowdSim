extends AbstractLevel

func _ready() -> void:
	super()
	_setup_goal_spawn_pairs()

func _setup_goal_spawn_pairs():
	spawn_goal_pairs.append([spawns[0], goals[4]])
	spawn_goal_pairs.append([spawns[1], goals[5]])
	spawn_goal_pairs.append([spawns[2], goals[6]])
	spawn_goal_pairs.append([spawns[3], goals[3]])
	spawn_goal_pairs.append([spawns[4], goals[2]])
	spawn_goal_pairs.append([spawns[5], goals[1]])
	spawn_goal_pairs.append([spawns[6], goals[0]])
	print(spawn_goal_pairs)

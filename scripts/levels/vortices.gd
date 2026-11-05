extends AbstractLevel

func _ready() -> void:
	super()
	_setup_goal_spawn_pairs()

func _setup_goal_spawn_pairs():
	print(spawns)
	print(goals)
	for i in range(0,4):
		for j in range(0,4):
			if i != j:
				spawn_goal_pairs.append([spawns[i], goals[j]])
	print(spawn_goal_pairs)

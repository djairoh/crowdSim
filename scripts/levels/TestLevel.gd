extends AbstractLevel

func _ready() -> void:
	super()
	_setup_goal_spawn_pairs()

func _setup_goal_spawn_pairs():
	# TODO: each implementation has to specify goal-spawn pairs
	print(self.spawns)
	print(self.goals)
	pass

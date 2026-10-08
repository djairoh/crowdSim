extends Node2D
class_name Behaviours

# Class that contains emergent behaviours
# falling, pushing, bottleneck avoidance

@onready var parent: CrowdAgent = get_parent()

@onready var falling: Falling = $Falling
@onready var bottleneck_avoidance: BottleneckAvoidance = %BottleneckAvoidance


func update(delta: float) -> void:
	bottleneck_avoidance.update(delta)

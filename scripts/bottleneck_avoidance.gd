extends Node
class_name BottleneckAvoidance

@onready var parent: CrowdAgent = get_parent().get_parent()

@onready var detection: CongestionDetection = $CongestionDetection
@onready var rerouting: PortalRerouting = $PortalRerouting


func update(delta: float) -> void:
	if not parent.agent_state.is_impatient():
		if rerouting.is_rerouting or detection.bottleneck_detected:
			reset()
		return

	rerouting.update_failed_portals(delta)
	detection.retry_timer = maxf(detection.retry_timer - delta, 0.0)

	if rerouting.is_rerouting:
		rerouting.update_rerouting(delta)
		return

	detection.update(delta)

	if not detection.bottleneck_detected:
		return

	if detection.retry_timer > 0.0:
		return

	detection.start_retry_cooldown()
	rerouting.try_start_rerouting()


func reset() -> void:
	rerouting.reset()

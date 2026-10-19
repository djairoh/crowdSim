extends Camera2D

# simple movable (zomable, pannable) camera

@export var minZoom := 1.0
@export var maxZoom := 5.0
@export var zoomFactor := 0.1
@export var zoomDuration := 0.2
@export var input_enabled := true
var zoomLevel: float = 2
var dragging: bool = false

func _ready():
	zoom = Vector2(zoomLevel, zoomLevel)

func _input(event):
	if input_enabled:
		if event.is_action_pressed("zoomIn"):
			setZoomLevel(zoomLevel + zoomFactor)
		elif event.is_action_pressed("zoomOut"):
			setZoomLevel(zoomLevel - zoomFactor)
		elif event.is_action_pressed("resetCamera"):
			reset()

func _unhandled_input(event):
	if input_enabled:
		if event is InputEventMouseButton:
			if event.get_button_index() == 3:
				dragging = event.is_pressed()
		elif event is InputEventMouseMotion:
			if dragging:
				self.global_position -= event.get_relative() * 1/zoomLevel
	
	
func set_input_enabled(b: bool):
	input_enabled = b

func setZoomLevel(level: float, mouse_world_position = self.get_global_mouse_position()):
	var old_zoomLevel = zoomLevel
	zoomLevel = clampf(level, minZoom, maxZoom)
	
	var direction = (mouse_world_position - global_position)
	var new_position = self.global_position + direction - ((direction) / (zoomLevel/old_zoomLevel))
	
	zoom = Vector2(zoomLevel, zoomLevel)
	self.global_position = new_position

func reset():
	self.global_position = Vector2(0, 0)

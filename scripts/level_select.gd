extends Control

@onready var buttons = $GridContainer
	
	
func create_level_buttons(crowd_manager):
	for lvl in crowd_manager.find_child("Levels").get_children():
		var button = Button.new()
		button.text = lvl.name
		button.custom_minimum_size = Vector2(100, 100)
		button.pressed.connect(crowd_manager.load_level.bind(lvl.name))
		buttons.add_child(button)

# FIXME: not entirely happy with how this turns out in-game.
func setCamera(camera: Camera2D):
	if buttons.get_child_count() == 0:
		return
	
	var rect = null
	for button in buttons.get_children():
		if rect == null:
			rect = Rect2(button.global_position, button.size)
		else:
			rect = rect.merge(Rect2(button.global_position, button.size))
	
	var center = rect.get_center()
	camera.global_position = center
	
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_x = rect.size.x / viewport_size.x
	var scale_y = rect.size.y / viewport_size.y
	camera.zoom = max(scale_x, scale_y) * 1.1

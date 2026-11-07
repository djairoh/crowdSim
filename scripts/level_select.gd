extends Control

@onready var buttons = $GridContainer
var buttons_created: bool = false
	
	
func create_level_buttons(crowd_manager):
	if buttons_created:
		return
		
	for lvl in crowd_manager.find_child("Levels").get_children():
		var button = Button.new()
		button.text = lvl.name
		button.custom_minimum_size = Vector2(100, 100)
		button.pressed.connect(crowd_manager.load_level.bind(lvl.name))
		buttons.add_child(button)
		
	buttons_created = true

func setCamera(camera: Camera2D):
	# wait a frame so the buttons exist for sure
	await get_tree().process_frame
	
	var children = buttons.get_children()
	if children.is_empty():
		return
		
	var rect: Rect2 = children[0].get_global_rect()
	for i in range(1, children.size()):
		rect = rect.merge(children[i].get_global_rect())
		
	camera.global_position = rect.get_center()
	camera.zoom = Vector2(1.5, 1.5) 

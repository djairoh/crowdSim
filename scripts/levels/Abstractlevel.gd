extends Node
class_name AbstractLevel

# abstract class containing functionality
# for each of our scenarios we should subclass this one
# or really just subclass the whole AbstractLevel scene tbh 

var goals: Array
var spawns: Array
var spawn_goal_pairs: Dictionary
@onready var tiles = $TileMapLayer

func _ready() -> void:
	# $NavigationRegion2D.bake_navigation_polygon()
	goals.append_array(_get_tiles_with_property("is_goal"))
	spawns.append_array(_get_tiles_with_property("is_spawn"))
		
func get_random_goal() -> Vector2:
	# TODO: what if no goals?
	return goals.pick_random()
	
func get_random_spawn() -> Vector2:
	return spawns.pick_random()
	# TODO: what if no spawns?

# helper func, used to get tiles marked as goals/spawns
func _get_tiles_with_property(property: String) -> Array:
	var out_tiles = []
	var cells = tiles.get_used_cells()
	
	for cell_pos in cells:
		var tile_data = tiles.get_cell_tile_data(cell_pos)
		
		if tile_data and tile_data.get_custom_data(property):
			out_tiles.append(tiles.map_to_local(cell_pos))
			
	return out_tiles

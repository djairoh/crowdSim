extends Node
class_name AbstractLevel

# abstract class containing functionality
# for each of our scenarios we should subclass this one
# or really just subclass the whole AbstractLevel scene tbh 

const DOOR_OPENED_TILE_ID = 5
const DOOR_CLOSED_TILE_ID = 4

var goals: Array
var spawns: Array
var door_cells: Array
@onready var tiles = $TileMapLayer

func _ready() -> void:
	# $NavigationRegion2D.bake_navigation_polygon()
	goals.append_array(_get_tiles_with_property("is_goal"))
	spawns.append_array(_get_tiles_with_property("is_spawn"))
	_get_door_poss()
		
func get_random_goal() -> Vector2:
	# TODO: what if no goals?
	return goals.pick_random()
	
func get_random_spawn() -> Vector2:
	return spawns.pick_random()
	# TODO: what if no spawns?

func is_door_open(cell: Vector2i) -> bool:
	var tile_data = tiles.get_cell_tile_data(cell)

	return (
		tile_data != null
		and tile_data.get_custom_data("is_door")
		and tile_data.get_custom_data("is_open")
	)

func toggle_all_doors():
	for cell in door_cells:
		var tile_data = tiles.get_cell_tile_data(cell)
		if tile_data:
			var is_open = tile_data.get_custom_data("is_open")
			tiles.set_cell(
				cell, 
				DOOR_CLOSED_TILE_ID if is_open else DOOR_OPENED_TILE_ID, 
				tiles.get_cell_atlas_coords(cell)
			)


func _get_door_poss():
	for cell in tiles.get_used_cells():
		var tile_data = tiles.get_cell_tile_data(cell)
		
		if tile_data and tile_data.get_custom_data("is_door"):
			door_cells.append(cell)

# helper func, used to get tiles marked as goals/spawns
func _get_tiles_with_property(property: String) -> Array:
	var out_tiles = []
	var cells = tiles.get_used_cells()
	
	for cell_pos in cells:
		var tile_data = tiles.get_cell_tile_data(cell_pos)
		
		if tile_data and tile_data.get_custom_data(property):
			out_tiles.append(tiles.map_to_local(cell_pos))
			
	return out_tiles

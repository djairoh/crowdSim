extends Node
class_name AbstractLevel

# abstract class containing functionality
# for each of our scenarios we should subclass this one
# or really just subclass the whole AbstractLevel scene tbh 

const DOOR_OPENED_TILE_ID = 5
const DOOR_CLOSED_TILE_ID = 4

var spawn_goal_pairs: Array
var goals: Array
var spawns: Array
var door_cells: Array
var portals: Array[Array] = []
@onready var tiles = $TileMapLayer

func _ready() -> void:
	goals.append_array(_get_tiles_with_property("is_goal"))
	spawns.append_array(_get_tiles_with_property("is_spawn"))
	_get_door_poss()
	_build_portals()
		
func get_random_goal() -> Vector2:
	return goals.pick_random()
	
func get_random_spawn() -> Vector2:
	return spawns.pick_random()

func get_spawn_goal_pair() -> Array:
	if spawn_goal_pairs.size() > 0:
		return spawn_goal_pairs.pick_random()
	return [get_random_spawn(), get_random_goal()]



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
func bake_nav_reg():
	$NavigationRegion2D.bake_navigation_polygon()
	
func _get_door_poss():
	for cell in tiles.get_used_cells():
		var tile_data = tiles.get_cell_tile_data(cell)
		
		if tile_data and tile_data.get_custom_data("is_door"):
			door_cells.append(cell)
	
			
func is_door_open(cell: Vector2i) -> bool:
	var tile_data = tiles.get_cell_tile_data(cell)

	return (
		tile_data != null
		and tile_data.get_custom_data("is_door")
		and tile_data.get_custom_data("is_open")
	)

# build portal from combining adjacent door tiles
func _build_portals() -> void:
	portals.clear()

	var remaining: Dictionary = {}

	for cell in door_cells:
		remaining[cell] = true

	while not remaining.is_empty():
		var start: Vector2i = remaining.keys()[0]
		var portal: Array[Vector2i] = []
		var pending: Array[Vector2i] = [start]

		remaining.erase(start)

		while not pending.is_empty():
			var cell: Vector2i = pending.pop_back()
			portal.append(cell)

			for direction in [
				Vector2i.UP,
				Vector2i.DOWN,
				Vector2i.LEFT,
				Vector2i.RIGHT
			]:
				var neighbor = cell + direction

				if remaining.has(neighbor):
					remaining.erase(neighbor)
					pending.append(neighbor)

		portals.append(portal)
		
func get_open_portal_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []

	for portal in portals:
		var center := Vector2.ZERO
		var all_open := true

		for cell in portal:
			if not is_door_open(cell):
				all_open = false
				break

			center += tiles.map_to_local(cell)

		if all_open:
			center /= portal.size()
			positions.append(tiles.to_global(center))

	return positions


# helper func, used to get tiles marked as goals/spawns
func _get_tiles_with_property(property: String) -> Array:
	var out_tiles = []
	var cells = tiles.get_used_cells()
	
	for cell_pos in cells:
		var tile_data = tiles.get_cell_tile_data(cell_pos)
		
		if tile_data and tile_data.get_custom_data(property):
			out_tiles.append(tiles.map_to_local(cell_pos))
			
	out_tiles.sort_custom(_sort_vec)
	return out_tiles
	
func _sort_vec(a, b):
	if a[0] == b[0]:
		return a[1] < b[1]
	return a[0] < b[0]

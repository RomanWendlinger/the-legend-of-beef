extends Node
class_name MapClusterLoader

# cant typehint MapCluster within
var clusterMap = XYMap.new()


@export var cluster_tile_width := 16
@export var cluster_tile_height := 16

@export var room_generator : RoomGenerator


@export_group("Target settings")
@export var wall_layer: TileMapLayer
@export var ground_layer: TileMapLayer
@export var tile_size: Vector2i

@export  var terrain_set: int
@export var terrain_wall_id: int
@export var terrain_ground_id: int
@export var background_filler_atlas_coords : Array[Vector2i]

@export var tileset_id: int


# ViewArea: x,y position
# w: width
# z: height
func loadClustersInView(viewArea: Rect2) -> void:
	var newGroundTileArray = []
	var newWallTilesArray = []
	var topMostClusterRow = floor(viewArea.position.y / cluster_tile_height / tile_size.y)
	var lowestClusterRow = floor((viewArea.position.y + viewArea.size.y) / cluster_tile_height/ tile_size.y)
	var leftClusterColumn = floor(viewArea.position.x / cluster_tile_width/ tile_size.x)
	var rightClusterColumn = floor((viewArea.position.x + viewArea.size.x) / cluster_tile_width/ tile_size.x)
	for clusterRow in range(topMostClusterRow, lowestClusterRow):
		for clusterColumn in range(leftClusterColumn, rightClusterColumn):
			
			var relativeClusterPosition = Vector2i(clusterColumn, clusterRow)
			var elem:MapCluster = clusterMap.get_element(relativeClusterPosition)
			#not in cache!
			if !elem:
				for in_cluster_row in cluster_tile_height:
					for in_cluster_column in cluster_tile_width:
						var backgroundElement = Vector2i((clusterColumn * cluster_tile_width) + in_cluster_column, clusterRow * cluster_tile_height + in_cluster_row )
						newWallTilesArray.append(backgroundElement)
				elem = createNewMapCluster(relativeClusterPosition)
				clusterMap.append(relativeClusterPosition, elem)
				newGroundTileArray.append_array(elem.groundTiles)
			
	
	if not newWallTilesArray.is_empty():
		for newBackgroundTile in newWallTilesArray:
			ground_layer.set_cell(newBackgroundTile, terrain_set, background_filler_atlas_coords.pick_random())
			wall_layer.set_cell(newBackgroundTile, terrain_set, Vector2i(9,2))
	if not newGroundTileArray.is_empty():
		#wall_layer.set_cells_terrain_connect(newWallTilesArray, terrain_set, terrain_wall_id )
		#wall_layer.set_cells_terrain_connect(newGroundTileArray, terrain_set, terrain_ground_id )
		for tile in newGroundTileArray:
			wall_layer.set_cell(tile, terrain_set, background_filler_atlas_coords.pick_random() )
	pass

func createNewMapCluster(clusterPosition: Vector2i) -> MapCluster:
	var newMapCluster = MapCluster.new()
	#create iRect to check if within bounds
	var clusterRect = Rect2i(clusterPosition, Vector2i(cluster_tile_width, cluster_tile_height))
	for row in range(cluster_tile_height * clusterPosition.y, cluster_tile_height * clusterPosition.y + (cluster_tile_height)):
		for col in range(cluster_tile_width * clusterPosition.x, cluster_tile_width * clusterPosition.x + cluster_tile_width):
			var elem = room_generator.groundTileMap.get_element(Vector2i(col, row))
			if elem:
				newMapCluster.groundTiles.append(Vector2i(col, row))
		
	return newMapCluster

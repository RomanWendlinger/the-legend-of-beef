@tool
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

@export_group("Masking")
@export var fog_layer: TileMapLayer  # Optional fog layer to hide unfinished terrain
@export var fog_tile_coords: Vector2i = Vector2i(0, 0)  # Coordinates of fog tile in tileset
@export var use_fade_animation: bool = true
@export var fade_duration: float = 0.5  # Duration of fade animation in seconds
@export var screen_fade_color: Color = Color.BLACK  # Color for screen fade transition

# Async terrain processing
var terrain_queue: Array[Dictionary] = []
var is_processing_terrain: bool = false
@export var tiles_per_frame: int = 50  # Number of tiles to process per frame
@export var initial_load_tiles_per_frame: int = 200  # Faster processing for initial visible area
var pending_tiles: Dictionary = {}  # Track tiles being generated
var is_initial_load: bool = true  # Track if this is the first load

# Screen fade overlay
var screen_fade_overlay: ColorRect = null

func _ready() -> void:
	set_process(true)
	_setup_screen_fade_overlay()

func _process(_delta: float) -> void:
	# Process terrain updates - multiple per frame during initial load for speed
	if not is_processing_terrain and terrain_queue.size() > 0:
		var data = terrain_queue.pop_front()
		_process_terrain_async(data)

	# Mark initial load as complete when queue is empty
	if is_initial_load and terrain_queue.size() == 0 and not is_processing_terrain:
		is_initial_load = false

func clearClusterCache() -> void:
	clusterMap = XYMap.new()
	is_initial_load = true  # Reset initial load flag when clearing cache

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

	# Calculate center of view area in cluster coordinates
	var viewCenterX = (viewArea.position.x + viewArea.size.x / 2.0) / (cluster_tile_width * tile_size.x)
	var viewCenterY = (viewArea.position.y + viewArea.size.y / 2.0) / (cluster_tile_height * tile_size.y)
	var centerCluster = Vector2(viewCenterX, viewCenterY)

	# Build list of clusters to load with their distances from center
	var clusters_to_load = []
	for clusterRow in range(topMostClusterRow, lowestClusterRow):
		for clusterColumn in range(leftClusterColumn, rightClusterColumn):
			var relativeClusterPosition = Vector2i(clusterColumn, clusterRow)
			var elem:MapCluster = clusterMap.get_element(relativeClusterPosition)
			#not in cache!
			if !elem:
				var distance = centerCluster.distance_to(Vector2(clusterColumn, clusterRow))
				clusters_to_load.append({
					"position": relativeClusterPosition,
					"distance": distance
				})

	# Sort clusters by distance from center (closest first)
	clusters_to_load.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# Process clusters in order of distance from center
	# Each cluster is processed and queued separately for better responsiveness
	for cluster_data in clusters_to_load:
		var relativeClusterPosition = cluster_data["position"]
		var clusterColumn = relativeClusterPosition.x
		var clusterRow = relativeClusterPosition.y
		var cluster_distance = cluster_data["distance"]

		var clusterWallTiles = []
		var clusterGroundTiles = []

		for in_cluster_row in cluster_tile_height:
			for in_cluster_column in cluster_tile_width:
				var backgroundElement = Vector2i((clusterColumn * cluster_tile_width) + in_cluster_column, clusterRow * cluster_tile_height + in_cluster_row )
				clusterWallTiles.append(backgroundElement)

		var elem = createNewMapCluster(relativeClusterPosition)
		clusterMap.append(relativeClusterPosition, elem)
		clusterGroundTiles.append_array(elem.groundTiles)

		# Set initial tiles immediately
		if not clusterWallTiles.is_empty():
			for newBackgroundTile in clusterWallTiles:
				ground_layer.set_cell(newBackgroundTile, terrain_set, background_filler_atlas_coords.pick_random())
				wall_layer.set_cell(newBackgroundTile, terrain_set, Vector2i(9,2))

				# Add fog to hide the tiles until terrain is properly set
				if fog_layer:
					fog_layer.set_cell(newBackgroundTile, terrain_set, fog_tile_coords)
				pending_tiles[newBackgroundTile] = true

		if not clusterGroundTiles.is_empty():
			# Add fog to ground tiles too
			if fog_layer:
				for tile in clusterGroundTiles:
					fog_layer.set_cell(tile, terrain_set, fog_tile_coords)
					pending_tiles[tile] = true

			# Queue each cluster's terrain data separately with priority
			var terrain_data = {
				"wall_tiles": clusterWallTiles,
				"ground_tiles": clusterGroundTiles,
				"terrain_set": terrain_set,
				"terrain_wall_id": terrain_wall_id,
				"terrain_ground_id": terrain_ground_id,
				"distance": cluster_distance  # Store distance for priority
			}
			terrain_queue.append(terrain_data)
	pass

func _process_terrain_async(data: Dictionary) -> void:
	is_processing_terrain = true

	var wall_tiles: Array = data["wall_tiles"]
	var ground_tiles: Array = data["ground_tiles"]
	var terrain_set_val: int = data["terrain_set"]
	var wall_id: int = data["terrain_wall_id"]
	var ground_id: int = data["terrain_ground_id"]

	# Use faster processing speed for initial load
	var current_tiles_per_frame = initial_load_tiles_per_frame if is_initial_load else tiles_per_frame

	# Process wall tiles in chunks
	var wall_index = 0
	while wall_index < wall_tiles.size():
		var chunk_size = min(current_tiles_per_frame, wall_tiles.size() - wall_index)
		var chunk = wall_tiles.slice(wall_index, wall_index + chunk_size)
		wall_layer.set_cells_terrain_connect(chunk, terrain_set_val, wall_id)
		wall_index += chunk_size
		if wall_index < wall_tiles.size():
			await get_tree().process_frame

	# Process ground tiles in chunks
	var ground_index = 0
	while ground_index < ground_tiles.size():
		var chunk_size = min(current_tiles_per_frame, ground_tiles.size() - ground_index)
		var chunk = ground_tiles.slice(ground_index, ground_index + chunk_size)
		wall_layer.set_cells_terrain_connect(chunk, terrain_set_val, ground_id)
		ground_index += chunk_size
		if ground_index < ground_tiles.size():
			await get_tree().process_frame

	# Remove fog and clear pending tiles when done
	if fog_layer:
		# Skip fade animation during initial load for faster startup
		if use_fade_animation and not is_initial_load:
			await _fade_out_fog(wall_tiles + ground_tiles)
		else:
			for tile in wall_tiles:
				fog_layer.erase_cell(tile)
			for tile in ground_tiles:
				fog_layer.erase_cell(tile)

		for tile in wall_tiles:
			pending_tiles.erase(tile)
		for tile in ground_tiles:
			pending_tiles.erase(tile)
	else:
		for tile in wall_tiles:
			pending_tiles.erase(tile)
		for tile in ground_tiles:
			pending_tiles.erase(tile)

	is_processing_terrain = false

func _setup_screen_fade_overlay() -> void:
	# Create a ColorRect that covers the entire screen
	screen_fade_overlay = ColorRect.new()
	screen_fade_overlay.color = screen_fade_color
	screen_fade_overlay.color.a = 0.0  # Start transparent

	# Make it cover the whole viewport
	screen_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_fade_overlay.z_index = 100  # On top of everything

	# Add to the scene tree
	# Try to add to a CanvasLayer for proper layering
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.name = "MapClusterFadeLayer"
	add_child(canvas_layer)
	canvas_layer.add_child(screen_fade_overlay)

func _fade_out_fog(tiles: Array) -> void:
	if not fog_layer or not screen_fade_overlay:
		return

	# Fade to black (screen covers everything)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(screen_fade_overlay, "color:a", 1.0, fade_duration * 0.5)

	await tween.finished

	# Remove the fog tiles while screen is black
	for tile in tiles:
		fog_layer.erase_cell(tile)

	# Fade back from black to reveal the new terrain
	var tween2 = create_tween()
	tween2.tween_property(screen_fade_overlay, "color:a", 0.0, fade_duration * 0.5)

	await tween2.finished

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

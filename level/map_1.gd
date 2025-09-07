extends Node
class_name Map


@onready var room_generator: RoomGenerator = $Geometry/RoomGenerator
@onready var enemy_spawner_job: EnemySpawner = $Geometry/EnemySpawnerJob
@onready var map_cluster_loader: MapClusterLoader = $Geometry/MapClusterLoader
@onready var camera_2d: Camera2D = $Geometry/Camera2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create_level()
	SignalBus.create_level_end_hole.connect(create_end_hole)
	
func _process(delta: float) -> void:
	
	var viewportRect = camera_2d.get_viewport_rect()
	# grow_individual based on size and zoom
	var zoom = camera_2d.zoom
	var zoomedViewport = viewportRect.grow_individual(
		(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
		(viewportRect.size.y * float(1 / zoom.y)) / 2.0,
		(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
		(viewportRect.size.y * float(1 / zoom.y)) / 2.0
		)
	# "0 is top left, 1 is center
	if camera_2d.anchor_mode:
		zoomedViewport.position = camera_2d.position - (zoomedViewport.size / Vector2(2,2))
	else:
		zoomedViewport.position = camera_2d.position
	
	var tilesCenter = viewportRect.position * camera_2d.get_transform() / 16
	var tilesSize = viewportRect.size * (Vector2(1,1) / zoom) / 16
	map_cluster_loader.loadClustersInView(zoomedViewport)
	

func create_level() -> void:
	#create level
	room_generator.create_rooms()
	var viewArea = camera_2d.get_viewport_rect()
	map_cluster_loader.loadClustersInView(viewArea)
	#add enemy spawner in room
	for room in room_generator.existing_rooms:
		enemy_spawner_job.create_spawner(room)
	SignalBus.start_pregame.emit()

func start_level() -> void:
	await PlayerManager.spawn_active_players()
	GuiManager.create_ingame_timer()
	SignalBus.start_ingame.emit()

func create_end_hole(position: Vector2) -> void:
	var holeElement: LevelEndHole = load("res://items/level_end_hole.tscn").instantiate()
	holeElement.global_position = position
	holeElement.target_map = "res://level/hub_area.tscn"
	get_tree().root.get_node("Main").call_deferred("add_child", holeElement)

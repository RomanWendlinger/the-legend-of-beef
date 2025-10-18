@tool
extends Node
class_name Map


@onready var room_generator: RoomGenerator = $Geometry/RoomGenerator
@onready var enemy_spawner_job: EnemySpawner = $Geometry/EnemySpawnerJob
@onready var destructible_spawner: DestructibleSpawner = $Geometry/DestructibleSpawner
@onready var map_cluster_loader: MapClusterLoader = $Geometry/MapClusterLoader
@onready var camera_2d: Camera2D = $Geometry/Camera2D

@export_tool_button("Create Levels") var create_rooms_action = editor_create_level
@export_tool_button("Load Viewport") var load_viewport_action = loadCurrentEditorView
@export_tool_button("Clear Cluster cache") var clear_cluster_action = clear_cluster_cache
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create_level()
	
	if not Engine.is_editor_hint():
		SignalBus.create_level_end_hole.connect(create_end_hole)
		
		
func reset_generated_content() -> void:
	room_generator.position = Vector2i(15,15)
	room_generator.existing_rooms = []
	map_cluster_loader.clearClusterCache()
	map_cluster_loader.wall_layer.clear()
	map_cluster_loader.ground_layer.clear()
func editor_create_level() -> void:
	reset_generated_content()
	
	create_level()
	loadCurrentEditorView()
	
func loadCurrentEditorView() -> void:
	var viewportRect = EditorInterface.get_editor_viewport_2d().get_visible_rect()
	var zoom = Vector2(get_viewport().get_final_transform().x.x, get_viewport().get_final_transform().y.y)
	var zoomedViewport = viewportRect.grow_individual(
		(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
		(viewportRect.size.y * float(1 / zoom.y)) / 2.0,
		(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
		(viewportRect.size.y * float(1 / zoom.y)) / 2.0
		)
	zoomedViewport.position = get_viewport().get_final_transform().origin * -1
	map_cluster_loader.loadClustersInView(zoomedViewport)
	
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		var viewportRect = camera_2d.get_viewport_rect()
		# grow_individual based on size and zoom
		var zoom = camera_2d.zoom
		var anchor_mode = camera_2d.anchor_mode
			
		var zoomedViewport = viewportRect.grow_individual(
				(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
				(viewportRect.size.y * float(1 / zoom.y)) / 2.0,
				(viewportRect.size.x * float(1 / zoom.x)) / 2.0,
				(viewportRect.size.y * float(1 / zoom.y)) / 2.0
				)
				# "0 is top left, 1 is center
		if anchor_mode:
			zoomedViewport.position = camera_2d.position - (zoomedViewport.size / Vector2(2,2))
		else:
			zoomedViewport.position = camera_2d.position
		map_cluster_loader.loadClustersInView(zoomedViewport)
	
func clear_cluster_cache() -> void:
	map_cluster_loader.clearClusterCache()

func create_level() -> void:
	reset_generated_content()
	#create level
	room_generator.create_rooms()
	var viewArea = camera_2d.get_viewport_rect()
	if  Engine.is_editor_hint():
		viewArea = EditorInterface.get_editor_viewport_2d().get_visible_rect() * EditorInterface.get_editor_viewport_2d().global_canvas_transform
		
	map_cluster_loader.loadClustersInView(viewArea)
	#add enemy spawner in room
	if not Engine.is_editor_hint():
		for room in room_generator.existing_rooms:
			enemy_spawner_job.create_spawner(room)
			destructible_spawner.spawn_destructibles_in_room(room)
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

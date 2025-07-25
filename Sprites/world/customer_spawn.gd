extends Node2D
#
## Preload NPC scene
#@export var npc_scene: PackedScene
#@export var spawn_interval: float = 1.0
#@export var max_npcs: int = 1
#
#var spawn_points: Array[Marker2D] = []
#var active_npcs: Array[Node2D] = []
#var spawn_timer: Timer
#
#func _ready():
	#
	#collect_spawn_points()
	#
	##spawn timer
	#spawn_timer = Timer.new()
	#spawn_timer.wait_time = spawn_interval
	#spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	#add_child(spawn_timer)
	#spawn_timer.start()
#
#func collect_spawn_points():
	## spawn points
	#for child in get_children():
		#if child is Marker2D:
			#spawn_points.append(child)
	#
	#print("Found ", spawn_points.size(), " spawn points")
	#
	#
#func spawn_npc():
	#if active_npcs.size() >= max_npcs:
		#return
	#
	#if spawn_points.is_empty():
		#print("No spawn points available!")
		#return
	#
	#if not npc_scene:
		#print("No NPC scene assigned!")
		#return
	#
	## Choose random spawn point
	#var _spawn_point = spawn_points[randi() % spawn_points.size()]
	#
	## Instantiate NPC
	#var npc = npc_scene.instantiate()
	#get_tree().current_scene.add_child(npc)
	#
#
	#npc.call_deferred("set_global_position", _spawn_point.global_position)
	#
#
#func _on_spawn_timer_timeout():
	#spawn_npc()
#
## Manual spawn function you can call from other scripts
#func spawn_at_specific_point(point_index: int):
	#if point_index >= 0 and point_index < spawn_points.size():
		#var spawn_point = spawn_points[point_index]
		#var npc = npc_scene.instantiate()
		#get_tree().current_scene.add_child(npc)
		#npc.global_position = spawn_point.global_positiona
		#npc.global_rotation = spawn_point.global_rotation
		#active_npcs.append(npc)

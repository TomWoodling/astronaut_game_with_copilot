extends Node3D

@onready var scene_cam: Camera3D = $SceneCamPivot/Camera3D
@onready var scene_cam_point = $SceneCamPivot
@onready var entrance_shape = $Entrance/CollisionShape3D
@onready var mid_blocker: StaticBody3D = $MidBlocker
@onready var obj_1: MissionObjective = $M1_TalkChad6
@onready var obj_2: MissionObjective = $M1_CollectRations
@onready var obj_3: MissionObjective = $M1_CollectDoodad
@onready var obj_4: MissionObjective = $M1_ReachLucyArea
@onready var obj_5: MissionObjective = $M1_TalkLucy
@onready var next_scene_path: String = "res://scenes/world.tscn"

signal obj_reset

# Called when the node enters the scene tree for the first time.
func _ready():
	# just force cutscene
	GameManager.set_gameplay_state(GameManager.GameplayState.CUTSCENE)
	var start_msg: Dictionary = {"text": "Welcome to the Cave - isn't it spooky!","color":"MAGENTA","duration":4.0}
	HUDManager.show_message(start_msg)
	_enter_playing_state()

func _enter_playing_state() -> void:
	# Ensure player starts not controllable - Cutscene again!
	# GameState handled by SceneManager once we aren't loading this one directly
	#GameManager.change_game_state(GameManager.GameState.PLAYING)
	#print("Crater: GameState set to PLAYING.")
	# Set mouse mode for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_startup_sequence()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _startup_sequence():
	scene_cam.current = true
	MissionManager.cutscene_walk = true
	MissionManager.emit_signal("request_cutscene_animation","Walk",true)
	await get_tree().create_timer(2.0).timeout
	MissionManager.emit_signal("request_cutscene_animation","Walk",false)
	MissionManager.cutscene_walk = false
	entrance_shape.disabled = false
	scene_cam.current = false
	GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)

func _obj_signal_handler(obj_id:String):
	match obj_id:
		"M1_CollectRations":
			mid_blocker.set_objective_active(false)
			mid_blocker.queue_free()
		"M1_CollectDoodad":
			pass
		"M1_ReachLucyArea":
			await get_tree().create_timer(2.0).timeout
			emit_signal("obj_reset")
		"M1_TalkLucy":
			await get_tree().create_timer(2.5).timeout
			var end_msg: Dictionary = {"text": "This completes mission 1 - go out and explore the world!","color":"GOLDENROD","duration":6.0}
			HUDManager.show_message(end_msg)
			await get_tree().create_timer(6.0).timeout
			MissionManager._complete_current_mission()
			start_multi_part_intro()

func start_multi_part_intro():
	print("Queueing intro sequence...")
	# Video 1: No pre-title, but has a post-title
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/l1_penult.ogv",
		"Lucy and Snaut do their best to encourage D00D4D, but the poor machine is missing its modules...", # No pre-title text
		"...but Lucy explains she has something to help!", # Post-title text shown after video 1
		3.0 # Duration for the post-title card
	)
	
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/level1_end.ogv",
		"This is the scanner, go out and scan everything you can...", # No pre-title text
		"...and best of luck, we're counting on you Snaut...", # Post-title text shown after video 1
		3.0 # Duration for the post-title card
	)

	# The first video will start playing automatically (if nothing else was playing)
	# The rest will play sequentially after the previous one finishes.
	print("Intro sequence queued.")

	# Optional: Wait for the entire queue to finish
	await SceneManager.cutscene_queue_completed
	print("Entire intro sequence finished!")
	# Now load the next scene, etc.
	SceneManager.change_scene(next_scene_path)

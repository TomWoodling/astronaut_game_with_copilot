extends Node3D

@export var exit_ready: bool = false

@onready var player = GameManager.player
@onready var start_platform: Node3D = $StartPlatform
@onready var start_anim: AnimationPlayer = $StartPlatform/AnimationPlayer
@onready var obj_1: MissionObjective = $M1_TalkChad4
@onready var obj_3: MissionObjective = $M1_CollectCarbon3
@onready var obj_4: MissionObjective = $M1_CollectCarbon4
@onready var obj_5: MissionObjective = $M1_TalkChad5
@onready var obj_final: MissionObjective = $M1_EnterCaveTrigger
@onready var collectables_remain: int = 2
@onready var blocker_1 = $Mainblocker/Blocker
@onready var scene_cam: Camera3D = $SceneCamPoint/SceneCam
@onready var scene_cam_anim: AnimationPlayer = $SceneCamPoint/AnimationPlayer
@onready var next_scene_path: String = "res://scenes/missions/mission1/mission1_cave.tscn"


# Called when the node enters the scene tree for the first time.
func _ready():
	_enter_playing_state()
	blocker_1.set_objective_active(true)

func _enter_playing_state() -> void:
	# Ensure player starts controllable - no actually we want a cutscene
	GameManager.set_gameplay_state(GameManager.GameplayState.CUTSCENE)
	_startup_sequence()
	# GameState handled by SceneManager once we aren't loading this one directly
	#GameManager.change_game_state(GameManager.GameState.PLAYING)
	#print("Crater: GameState set to PLAYING.")
	# Set mouse mode for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _startup_sequence():
	var start_msg: Dictionary = {"text": "Welcome to the Canyon!","color":"MAGENTA","duration":4.0}
	HUDManager.show_message(start_msg)
	start_anim.play("descend")
	await get_tree().create_timer(1.0).timeout
	MissionManager.cutscene_fall = true

	#MissionManager.cutscene_fall = false
	#GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"descend":
			#GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
			pass
		"zoom":
			#SceneManager.change_scene(next_scene_path)
			pass


func _on_blocker_warning_area_entered(area):
	if area.is_in_group("player"):
		var warn_msg: Dictionary = {"text": "Talk to the CHADstronaut first","color":"BURLYWOOD","duration":1.0}
		HUDManager.show_message(warn_msg)


func _on_challenge_collectable_3_collected(item_id):
	obj_3.report_trigger_met()
	
func _on_challenge_collectable_4_collected(item_id):
	obj_4.report_trigger_met()

func _on_exit_area_body_entered(body):
	if body.is_in_group("player"):
		if exit_ready == true:
			end_sequence()
		else:
			var warn_msg: Dictionary = {"text": "Talk to the CHADstronaut first","color":"BURLYWOOD","duration":1.0}
			HUDManager.show_message(warn_msg)

func end_sequence():
	var complete_msg: Dictionary = {"text": "Canyon is complete, excellent work Snaut","color":"FOREST_GREEN","duration":10.0}
	HUDManager.show_message(complete_msg)
	GameManager.set_gameplay_state(GameManager.GameplayState.CUTSCENE)
	scene_cam.current = true
	await get_tree().create_timer(1.0).timeout
	scene_cam_anim.play("zoom")
	obj_final.report_trigger_met()

func _on_chad_5_dialog_area_dialog_finished(outcome):
	exit_ready = true


func _on_chad_4_dialog_area_dialog_finished(outcome):
	blocker_1.set_objective_active(false)

func _obj_signal_handler(obj_id:String):
	pass

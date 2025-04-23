extends Node3D

@onready var obj_1: MissionObjective = $M1_TalkChad2
@onready var obj_2: MissionObjective = $M1_TalkChad3
@onready var obj_3: MissionObjective = $M1_CollectCarbon1
@onready var obj_4: MissionObjective = $M1_CollectCarbon2
@onready var obj_5: MissionObjective = $M1_CraterExitButton
@onready var obj_final: MissionObjective = $M1_CraterExitPlatformArea
@onready var final_shape: CollisionShape3D = $M1_CraterExitPlatformArea/CompletionArea/CollisionShape3D
@onready var scene_cam_pivot: Node3D = $SceneCamPivot
@onready var scene_cam_active: bool = false
@onready var scene_cam: Camera3D = $SceneCamPivot/Camera3D
@onready var rotation_speed: float = 0.5
@onready var end_point = $M1_CraterExitPlatformArea/PlayerPoint
@onready var player = GameManager.player
@onready var popup_launcher: PopupLauncher = $M1_CraterExitButton/panel_1
@onready var end_platform = $M1_CraterExitPlatformArea/LiftPlatform
@onready var next_scene: String = "res://scenes/missions/mission1/mission1_canyon.tscn"

# Called when the node enters the scene tree for the first time.
func _ready():
	obj_final.visible = false
	final_shape.disabled = true
	_enter_playing_state()

# Keep scene entry logic
func _enter_playing_state() -> void:
	GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if scene_cam_active:
		scene_cam_pivot.rotate(Vector3.UP, rotation_speed * delta)

# Handle signals for missions
func _on_challenge_collectable_2_collected(_item_id):
	obj_3.report_trigger_met()

func _on_challenge_collectable_collected(_item_id):
	obj_4.report_trigger_met()

func _on_panel_1_minigame_completed(success):
	obj_5.report_trigger_met()
	obj_final.visible = true
	final_shape.disabled = false

func _on_completion_area_body_entered(body):
	if body.is_in_group("player"):
		obj_final.report_trigger_met()
		scene_cam_active = true
		scene_cam.current = true
		GameManager.set_gameplay_state(GameManager.GameplayState.CUTSCENE)
		await get_tree().create_timer(2.0).timeout
		var complete_msg: Dictionary = {"text": "Crater is complete - well done Snaut!","color":"GREEN","duration":10.0}
		HUDManager.show_message(complete_msg)
		player.global_transform.origin = end_point.global_transform.origin
		await get_tree().create_timer(10.0).timeout
		scene_cam.current = false
		end_platform._lift_platform()
		await get_tree().create_timer(5.0).timeout

func _obj_signal_handler(obj_id:String):
	pass

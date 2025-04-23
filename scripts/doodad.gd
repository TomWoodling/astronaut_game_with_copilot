extends StaticBody3D

@export var objective: MissionObjective = null
@export var popup_handler: PopupLauncher = null
@export var main_mission_node: Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var doodad_mesh = $doodad
@onready var emit_particles: GPUParticles3D = $GPUParticles3D
@onready var player_detect: Area3D = $PlayerDetect
@onready var indicator_light: OmniLight3D = $OmniLight3D
@onready var in_range: bool = false
@onready var doodad_msg: Dictionary = {"text": "This looks like a D00D4D! Try interacting with it!","color":"FOREST_GREEN","duration":2.5}
enum doodadState {
	INACTIVE,
	PENDING,
	PROCESSING,
	WAITING,
	FINISHED
	}
@onready var current_doodad_state: doodadState = doodadState.INACTIVE

signal changed_doodad_state(new_state:doodadState)
signal main_mission_signal(doodad_call:String)

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("changed_doodad_state", _on_change_doodad_state)
	emit_particles.emitting = false
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_player_detect_area_entered(area):
	if area.is_in_group("player"):
		if current_doodad_state == doodadState.PENDING:
			anim_player.play("PENDING")
			MissionManager.mission_interactable = self
			HUDManager.show_message(doodad_msg)
		if current_doodad_state == doodadState.PROCESSING:
			var proc_msg: Dictionary = {"text": "D00D4D is processing, wait a short while","color":"FOREST_GREEN","duration":2.5}
			HUDManager.show_message(proc_msg)

func _on_player_detect_area_exited(area):
	pass # Replace with function body.

func _set_doodad_state(new_state: doodadState):
	if current_doodad_state == new_state:
		return
	else:
		current_doodad_state = new_state
		emit_signal("changed_doodad_state",new_state)
		
func _on_change_doodad_state(new_state:doodadState):
	anim_player.stop()
	match new_state:
		doodadState.INACTIVE:
			indicator_light.visible = false
		doodadState.PENDING:
			indicator_light.visible = true
		doodadState.PROCESSING:
			indicator_light.visible = true
			anim_player.play("PROCESSING")
		doodadState.WAITING:
			if popup_handler:
				pass
			anim_player.play("PENDING")
		doodadState.FINISHED:
			if objective:
				objective.report_trigger_met()
			indicator_light.light_color = "FOREST_GREEN"
			emit_signal("main_mission_signal", objective.objective_id)
	

func interact():
	if current_doodad_state == doodadState.PENDING:
		_set_doodad_state(doodadState.PROCESSING)
		await get_tree().create_timer(10.0).timeout
		_set_doodad_state(doodadState.FINISHED)

func set_objective_active(activate):
	if activate == true:
		if current_doodad_state != doodadState.PENDING:
			current_doodad_state = doodadState.PENDING
	else:
		if current_doodad_state != doodadState.INACTIVE:
			current_doodad_state = doodadState.INACTIVE

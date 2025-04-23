extends Area3D
class_name ObjectiveDialogArea


@export var objective: MissionObjective
@export var npc: NPController
@export var main_mission_node: Node3D
@export var dialog_complete: bool = false
@export var in_range: bool = false
@export var is_inactive: bool

@onready var objective_id
@onready var player = GameManager.player
@onready var dialog_container: DialogContainer
@onready var coll_shape: CollisionShape3D = $CollisionShape3D

signal dialog_finished(outcome)
signal main_mission_signal(obj_id:String)

# Called when the node enters the scene tree for the first time.
func _ready():
	var area: Area3D = null
	# Set objective ID to parent
	objective_id = objective.objective_id
	connect("area_entered", _objective_dialog_area_area_entered)
	connect("area_exited", _objective_dialog_area_area_exited)
	connect("main_mission_signal", main_mission_node._obj_signal_handler)
	_build_dialog()
	# Match objective active status
	is_inactive = objective.starts_inactive
	if is_inactive:
		npc.visible = false
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if in_range:
		npc.look_at(player.global_transform.origin,Vector3.UP, true)

func interact():
	if in_range:
		if not dialog_complete:
			HUDManager.dialog_over.connect(objective_dialog_complete)
			GameManager.set_gameplay_state(GameManager.GameplayState.DIALOGUE)
			HUDManager.show_dialog(dialog_container)
		else:
			HUDManager.show_message({"text": "Already spoken to " + str(npc.display_name),"color":"TOMATO","duration":1.5})
		
		
	
func _objective_dialog_area_area_entered(area):
	if area.is_in_group("player"):
		npc.start_interaction_state()
		in_range = true
		if not dialog_complete:
			MissionManager.mission_interactable = self
	
func _objective_dialog_area_area_exited(area):
	if area.is_in_group("player"):
		npc.end_interaction_state()
		MissionManager.mission_interactable = null
		in_range = false
		
func is_scanned() -> bool:
	# This always returns false to ensure the interaction system 
	# considers this object interactable
	return false

func _build_dialog():
	# We really need to build a dialog container from JSON files or something
	# For now we'll keep it basic:
	var new_container: DialogContainer = DialogContainer.new()
	var objective_test: String = "Does this complete " + str(objective_id)
	new_container.add_entry(npc.display_name,"Hi Snaut test message " + str(objective_id),"neutral","Talk")
	new_container.add_entry("Snaut","Hi NPC test reply " + str(objective_id),"neutral","Talk")
	new_container.add_entry(npc.display_name,objective_test,"positive","Mood1")
	dialog_container = new_container

func objective_dialog_complete():
	objective.report_trigger_met()
	GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
	emit_signal("dialog_finished","neutral")
	emit_signal("main_mission_signal", objective_id)

func set_objective_active(activate):
	if activate == true:
		if npc.visible == false:
			npc.visible = true
		coll_shape.disabled = false
	else:
		coll_shape.disabled = true

extends Area3D
class_name ObjectiveBasicArea

@export var objective: MissionObjective
@export var handle_objective_node: Node3D
@export var main_mission_node: Node3D
@export var in_range: bool = false
@export var is_inactive: bool
@export var can_collect: bool

@onready var objective_id
@onready var is_complete: bool = false
@onready var player = GameManager.player
@onready var coll_shape: CollisionShape3D = $CollisionShape3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

signal main_mission_signal(obj_id:String)


# Called when the node enters the scene tree for the first time.
func _ready():
	objective_id = objective.objective_id
	connect("area_entered", _objective_basic_area_area_entered)
	connect("area_exited", _objective_basic_area_area_exited)
	anim_player.connect("animation_finished", _on_anim_player_animation_finished)
	connect("main_mission_signal", main_mission_node._obj_signal_handler)
	main_mission_node.connect("obj_reset", _handle_reset)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if in_range:
		if not is_complete:
			anim_player.play("in_range")
		

func interact():
	if not is_inactive and not is_complete and in_range:
		is_complete = true
		anim_player.stop()
		if can_collect:
			anim_player.play("collect")
		else:
			anim_player.play("finish")

func _objective_basic_area_area_entered(area:Area3D):
	if area.is_in_group("player") and not is_inactive:
		print("in area")
		in_range = true
		MissionManager.mission_interactable = self
	
func _objective_basic_area_area_exited(area:Area3D):
	if area.is_in_group("player") and not is_inactive:
		in_range = false
		MissionManager.mission_interactable = null

func set_objective_active(activate):
	if activate == true:
		objective.is_active = true
		is_inactive = false
	else:
		is_inactive = true

func _on_anim_player_animation_finished(anim_name: String):
	match anim_name:
		"collect":
			handle_objective_node.queue_free()
			objective.report_trigger_met()
			set_objective_active(false)
			emit_signal("main_mission_signal",objective_id)
			is_inactive = true
		"finish":
			objective.report_trigger_met()
			set_objective_active(false)
			emit_signal("main_mission_signal",objective_id)
			is_inactive = true

func _handle_reset():
	anim_player.play("RESET")

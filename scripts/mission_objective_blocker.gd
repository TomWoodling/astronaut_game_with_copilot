extends StaticBody3D

@onready var blocker_shape: CollisionShape3D = $CollisionShape3D
@onready var warn_area: Area3D = $BlockerWarning
@export var mission_message: String
@export var color_choice: Color
@export var duration: float
@onready var blocker_msg: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready():
	warn_area.connect("area_entered", _on_warn_area_entered)
	blocker_msg = {"text": mission_message,"color":color_choice,"duration":duration}


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_objective_active(activate: bool):
	#print("blocker received call "+str(activate))
	if activate == true:
		blocker_shape.disabled = false
		warn_area.monitoring = true
	else:
		blocker_shape.disabled = true
		warn_area.monitoring = false

func _on_warn_area_entered(area: Area3D):
	if area.is_in_group("player"):
		HUDManager.show_message(blocker_msg)

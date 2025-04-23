extends StaticBody3D
class_name PopupLauncher

enum PassState {
	INACTIVE,
	READY,
	COMPLETE
}

signal popup_launched
signal state_changed(previous_state, new_state)
signal minigame_completed(success)

@export var current_pass_state : PassState = PassState.INACTIVE 
@export var popup_scene : PackedScene
@export var minigame_scene : PackedScene
@export var interaction_range : float = 2.0

@onready var red_light : OmniLight3D = %RedLight
@onready var blue_light : OmniLight3D = %BlueLight
@onready var green_light : OmniLight3D = %GreenLight
@onready var interaction_area : Area3D = $InteractionArea
@onready var interaction_shape : CollisionShape3D = $InteractionArea/CollisionShape3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Setup the interaction area similar to ScanArea in ScannableObject
	var shape := BoxShape3D.new()
	shape.size.y = interaction_range
	shape.size.z = interaction_range
	interaction_shape.shape = shape
	
	# Set interaction area to layer 8 to be detected by player's interaction system
	interaction_area.collision_layer = 0  # Clear existing layers
	interaction_area.collision_layer = interaction_area.collision_layer | (1 << 7)  # Set layer 8
	
	# Initialize state visuals
	_update_state_visuals()

func interact() -> void:
	# This method will be called by the player's interaction system
	if current_pass_state == PassState.READY:
		if popup_scene:
			var popup_instance = popup_scene.instantiate()
			
			# Connect signals
			popup_instance.popup_closed.connect(_on_popup_closed)
			if popup_instance.has_signal("minigame_completed"):
				popup_instance.minigame_completed.connect(_on_minigame_completed)
			
			# Initialize with minigame if available
			if popup_instance.has_method("initialize") and minigame_scene:
				popup_instance.initialize(minigame_scene)
			# Add to scene
			get_tree().root.add_child(popup_instance)
			
			# Signal that popup was launched
			emit_signal("popup_launched")
	
	if current_pass_state == PassState.INACTIVE:
		var messagedict : Dictionary = {"text": "Not ready - try completing other objectives first","color":"CRIMSON","duration":2.0}
		HUDManager.show_message(messagedict)

func _on_popup_closed(confirmed):
	# Handle popup closure
	if confirmed:
		# Logic for confirmed action
		pass

func _on_minigame_completed(success):
	# Handle minigame completion
	emit_signal("minigame_completed", success)
	
	if success:
		# Change state to complete if minigame was successful
		_change_pass_state(PassState.COMPLETE)

func _update_state_visuals() -> void:
	match current_pass_state:
		PassState.READY:
			red_light.visible = false
			green_light.visible = false
			blue_light.visible = true
		PassState.COMPLETE:
			red_light.visible = false
			green_light.visible = true
			blue_light.visible = false
		PassState.INACTIVE:
			red_light.visible = true
			green_light.visible = false
			blue_light.visible = false

func _change_pass_state(new_state: PassState) -> void:
	if current_pass_state == new_state:
		return
	
	var previous_state = current_pass_state
	current_pass_state = new_state
	
	# Update visual indicators
	_update_state_visuals()
	
	# Emit signal about state change
	emit_signal("state_changed", previous_state, current_pass_state)

# Public method to change state from other scripts
func change_pass_state(new_state: PassState) -> void:
	_change_pass_state(new_state)

# Public method for highlight handling (required by player interaction system)
func highlight_in_range(is_in_range: bool) -> void:
	# Optional: Add visual feedback when player is in range
	pass

# Method for compatibility with the interaction system
func is_scanned() -> bool:
	# This always returns false to ensure the interaction system 
	# considers this object interactable
	return false

func set_objective_active(activate):
	if activate == true:
		_change_pass_state(PassState.READY)
		print("panel ready")
	else:
		_change_pass_state(PassState.INACTIVE)
		print("panel NOT ready")

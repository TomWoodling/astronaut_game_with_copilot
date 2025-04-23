# res://scripts/mission/mission_objective.gd
extends Node # Or Node3D if spatial position is inherently useful
class_name MissionObjective

## Represents a logical objective point within a mission.
## Acts as a container and communication hub for the actual trigger mechanism (child node).
## Emits 'objective_triggered' when its specific condition is met via its trigger child.

signal objective_triggered(objective_id: String)

# Identifies this specific objective instance. MUST BE UNIQUE within the mission.
# Best Practice: Set the NODE NAME in the scene tree to match this ID.
@export var objective_id: String = ""

# Does this objective need to be explicitly activated by MissionManager?
@export var starts_inactive: bool = false
# Should this objective deactivate itself (and its trigger) after firing once?
@export var trigger_once: bool = true

# Internal state
var is_active: bool = true

# --- Initialization ---
func _ready():
	if objective_id.is_empty():
		# Use the node's name as the ID if not set in inspector (Recommended workflow)
		objective_id = name
		if objective_id.is_empty() or objective_id == "MissionObjective": # Default Node name check
			push_error("MissionObjective node needs a unique Name assigned in the Scene Tree (or set objective_id export)!")
			is_active = false # Disable if no ID
			return

	# Connect to the MissionManager ONLY ONCE
	# Check if MissionManager exists before connecting
	var mm = get_node_or_null("/root/MissionManager")
	if mm:
		# Connect this objective's signal TO the MissionManager's handler
		objective_triggered.connect(mm.handle_objective_trigger)
		print("MissionObjective '%s' connected to MissionManager." % objective_id)
	else:
		push_error("MissionObjective '%s' could not find MissionManager to connect signal!" % objective_id)
		is_active = false # Can't function without manager

	if starts_inactive:
		set_active(false)
	else:
		set_active(true) # Ensure initial state is applied

# --- Public Method for Child Triggers ---

## Called by the child trigger mechanism (Area3D script, interactable script, button signal)
## when the physical trigger condition is met.
func report_trigger_met():
	if not is_active: return # Do nothing if logically inactive

	print("MissionObjective '%s' received trigger confirmation." % objective_id)
	var complete_msg: Dictionary = {"text": "%s is complete - well done Snaut!" % objective_id,"color":"GOLD","duration":2.0}
	HUDManager.show_message(complete_msg)
	emit_signal("objective_triggered", objective_id)

	if trigger_once:
		set_active(false) # Deactivate after firing

# --- Activation Control (Called by MissionManager) ---

func set_active(activate: bool):
	if is_active == activate: return # No change needed

	is_active = activate
	print("MissionObjective '%s': Active set to %s" % [objective_id, activate])

	# Enable/disable the *child trigger mechanism(s)*
	for child in get_children():
		# Just check for a method
		if child.has_method("set_objective_active"): # Example custom method
			child.set_objective_active(activate)
			print(child)

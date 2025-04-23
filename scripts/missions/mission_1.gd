# res://scripts/missions/mission_1.gd
extends MissionBase # Inherit from MissionBase

const MISSION_ID = "M1_Find_D00D4D"
const STEPS = [
	["M1_TalkChad2", "M1_TalkChad3", "M1_CollectCarbon1", "M1_CollectCarbon2"], # Step 0: Crater Group
	"M1_CraterExitButton",                 # Step 1
	"M1_CraterExitPlatformArea",           # Step 2
	"M1_TalkChad4",                        # Step 3
	["M1_CollectCarbon3", "M1_CollectCarbon4"], # Step 4: Canyon Carbon Group
	"M1_TalkChad5",                        # Step 5
	"M1_EnterCaveTrigger",                 # Step 6
	"M1_TalkChad6",                        # Step 7
	"M1_CollectRations",                   # Step 8
	"M1_CollectDoodad",                    # Step 9
	"M1_ReachLucyArea",                    # Step 10
	"M1_TalkLucy",                         # Step 11
]

# --- State ---
var current_step_index: int = -1
var completed_objective_ids: Dictionary = {} # Key: objective_id, Value: true

# --- Mission Lifecycle Overrides ---

func _ready():
	# Optional: Initialization specific to Mission 1 node itself
	mission_id = MISSION_ID # Set mission ID

func start_mission():
	is_active = true
	# TODO: Implement loading from ProgressionManager via load_mission_state
	if current_step_index < 0: # Check if resuming or starting fresh
		print("Mission 1: Starting fresh.")
		completed_objective_ids.clear()
		current_step_index = 0
	else:
		print("Mission 1: Resuming at step %d." % current_step_index)

	# Initial processing will be triggered by MM._on_scene_loaded
	print("Mission 1: Initialized state. Ready for first scene load.")

func stop_mission():
	print("Mission 1: Stopping.")
	is_active = false
	# Perform any Mission 1 specific cleanup if needed

# Optional: Implement saving/loading specific state for this mission
# func load_mission_state(data: Dictionary):
# 	current_step_index = data.get("index", -1)
# 	completed_objective_ids = data.get("completed_ids", {})
# 	print("Mission 1: Loaded state. Index: %d" % current_step_index)
#
# func get_mission_save_state() -> Dictionary:
# 	return {
# 		"index": current_step_index,
# 		"completed_ids": completed_objective_ids
#	}

# --- Core Logic Overrides ---

func handle_objective_trigger(objective_id: String):
	if not is_active or current_step_index < 0 or current_step_index >= STEPS.size():
		return

	if completed_objective_ids.has(objective_id):
		print("Mission 1: Objective '%s' already completed, ignoring trigger." % objective_id)
		return # Avoid processing redundant triggers

	completed_objective_ids[objective_id] = true
	print("Mission 1: Objective '%s' marked complete." % objective_id)
	# TODO: Save state via ProgressionManager.store_mission_save_state(mission_id, get_mission_save_state())

	var current_step_definition = STEPS[current_step_index]
	var step_complete = _check_step_completion(current_step_definition)

	if step_complete:
		print("Mission 1: Step %d completed!" % current_step_index)
		_perform_step_actions(current_step_definition) # Perform actions (may emit signals)
		_advance_step() # Advance logic immediately
	else:
		# Must be an incomplete group step
		print("Mission 1: Objective '%s' done, but step %d needs more." % [objective_id, current_step_index])
		_update_step_ui(current_step_definition) # Update UI progress
		# Deactivate the just-completed objective within the group
		_update_objective_activation(current_step_definition)


func _process_current_step():
	if not is_active or current_step_index < 0:
		request_ui_update.emit("No active mission.")
		return

	if current_step_index >= STEPS.size():
		print("Mission 1: All steps finished.")
		_complete_mission()
		return

	var current_step_definition = STEPS[current_step_index]
	print("Mission 1: Processing Step %d: %s" % [current_step_index, current_step_definition])
	_update_step_ui(current_step_definition)
	_update_objective_activation(current_step_definition)


# --- Internal Helpers ---

func _check_step_completion(step_definition) -> bool:
	"""Checks if all required objectives for the given step definition are complete."""
	if step_definition is String:
		return completed_objective_ids.has(step_definition)
	elif step_definition is Array:
		for required_id in step_definition:
			if not completed_objective_ids.has(required_id):
				return false # Found an incomplete objective in the group
		return true # All objectives in the group are complete
	else:
		push_error("Mission 1: Invalid step definition type in _check_step_completion.")
		return false


func _advance_step():
	if current_step_index < STEPS.size() - 1:
		current_step_index += 1
		print("Mission 1: Advanced to step %d." % current_step_index)
		# TODO: Save state via ProgressionManager
		_process_current_step() # Process the newly advanced step
	else:
		# Already on the last step, completing it triggers mission end
		_complete_mission()


func _update_step_ui(step_definition):
	var text = "Objective: Error"
	if step_definition is String:
		var objective_id = step_definition
		match objective_id:
			"M1_CraterExitButton": text = "Activate the exit platform."
			"M1_CraterExitPlatformArea": text = "Board the exit platform."
			"M1_TalkChad4": text = "Explore the canyon. Find CHADstronaut #4."
			"M1_TalkChad5": text = "Find CHADstronaut #5 near the cave entrance."
			"M1_EnterCaveTrigger": text = "Enter the cave."
			"M1_TalkChad6": text = "Explore the cave. Find CHADstronaut #6."
			"M1_CollectRations": text = "Find the 'special' rations."
			"M1_CollectDoodad": text = "Find the missing D00D4D."
			"M1_ReachLucyArea": text = "Investigate the strange noises."
			"M1_TalkLucy": text = "Talk to the mysterious figure."
			_: text = "Objective: %s" % objective_id # Default for unhandled single steps

	elif step_definition is Array:
		var group_id = step_definition[0] if not step_definition.is_empty() else "UnknownGroup"
		var tasks = []
		var total_in_group = step_definition.size()
		var completed_in_group = 0
		for objective_id in step_definition:
			if completed_objective_ids.has(objective_id):
				completed_in_group += 1
			else:
				var task_text = objective_id.replace("M1_", "").replace("Collect", "Collect ").replace("Talk", "Talk to ")
				tasks.append(task_text)
		# Determine UI text based on group
		if group_id.begins_with("M1_TalkChad2"): # Crater Group
			text = "In Crater: " + (" / ".join(tasks) if not tasks.is_empty() else "Requirements Met!")
		elif group_id.begins_with("M1_CollectCarbon3"): # Canyon Carbon Group
			text = "In Canyon: " + ("Collect Carbon (%d/%d)" % [completed_in_group, total_in_group] if not tasks.is_empty() else "Carbon Collected!")
		else: # Default group text
			text = "Complete Tasks (%d/%d): %s" % [completed_in_group, total_in_group, " / ".join(tasks)]

	request_ui_update.emit(text) # Signal MM to update HUD


func _update_objective_activation(step_definition):
	var active_ids_for_this_step = []
	if step_definition is String:
		# Single step: activate if not complete (usually only relevant if trigger_once=false)
		if not completed_objective_ids.has(step_definition):
			active_ids_for_this_step.append(step_definition)
	elif step_definition is Array:
		# Group step: activate all objectives in the group that are not yet complete
		for objective_id in step_definition:
			if not completed_objective_ids.has(objective_id):
				active_ids_for_this_step.append(objective_id)

	# Use the helper from MissionBase to activate/deactivate nodes in the current scene
	var tree = get_tree()
	if not tree: return # Should not happen if called correctly
	for node in tree.get_nodes_in_group("mission_objectives"):
		if is_instance_valid(node) and node is MissionObjective:
			var should_be_active = (node.objective_id in active_ids_for_this_step)
			_set_objective_active_in_scene(node.objective_id, should_be_active)


func _perform_step_actions(step_definition):
	"""Perform non-state-changing actions when a step completes."""
	var representative_id = step_definition[0] if step_definition is Array else step_definition
	print("Mission 1: Performing actions for completed step: %s" % representative_id)

	match representative_id:
		"M1_CraterExitPlatformArea":
			# Request scene change AFTER current scene's outro
			emit_signal("request_scene_change_after_outro", "res://scenes/missions/mission1/mission1_canyon.tscn")
		"M1_CollectCarbon3": # Identifier for Canyon Carbon Group
			report_mission_flag.emit("SQ_CarbonCollected") # Report flag on group completion
		"M1_EnterCaveTrigger":
			# Request scene change AFTER current scene's outro
			emit_signal("request_scene_change_after_outro", "res://scenes/missions/mission1/mission1_cave.tscn")
		"M1_CollectRations":
			report_mission_flag.emit("SQ_RationsFound") # Report flag on item collection
		"M1_CollectDoodad":
			report_key_item_acquired.emit("D00D4D") # Report item acquisition
		"M1_TalkLucy":
			# Last step - completion is handled when _advance_step moves past this index.
			# The actual scene change out of the cave is handled by mission_1_cave.gd's outro sequence.
			print("Mission 1: Final step 'M1_TalkLucy' complete logic finished.")
		_:
			# Default: No specific action for this step completion
			pass


func _complete_mission():
	if not is_active: return
	print("Mission 1: Completing mission %s." % mission_id)
	is_active = false
	mission_completed.emit(mission_id) # Signal MM

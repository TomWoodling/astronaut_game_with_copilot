# res://scripts/missions/mission_base.gd
class_name MissionBase
extends Node

# Signals emitted BY this mission node, handled BY MissionManager
signal request_ui_update(objective_text: String)
signal report_mission_flag(flag_name: String)
signal report_ability_unlock(ability_name: String)
signal report_key_item_acquired(item_id: String)
signal request_dialogue(dialog_container: DialogContainer)
signal request_cutscene_animation(anim_name: String, status: bool)
signal mission_completed(mission_id: String) # Signal when this mission is fully done
# Use this signal when a scene change should happen AFTER the current scene's outro
signal request_scene_change_after_outro(next_scene_path: String)
# (Optional: Add 'request_scene_change_immediate' if ever needed)

# Properties managed by MissionManager
var mission_id: String = ""
var is_active: bool = false

# --- Methods to be overridden by specific mission scripts ---

func start_mission():
	push_error("MissionBase: start_mission() must be overridden!")

func handle_objective_trigger(objective_id: String):
	push_error("MissionBase: handle_objective_trigger() must be overridden! Received: %s" % objective_id)

func load_mission_state(data: Dictionary):
	# Override to load mission-specific progress (e.g., index, completed IDs)
	pass

func get_mission_save_state() -> Dictionary:
	# Override to return mission-specific progress
	return {}

func stop_mission():
	is_active = false
	# Override for any cleanup specific to this mission

func _process_current_step():
	# Needs to be implemented in derived class (like Mission1)
	push_error("MissionBase: _process_current_step() must be overridden!")

# Helper to find and activate/deactivate objectives in the current scene
func _set_objective_active_in_scene(objective_id: String, activate: bool):
	# Find the objective node - assumes objectives are consistently grouped
	# This requires the node calling it (Mission1) to be IN the tree.
	var tree = get_tree()
	if not tree:
		push_error("MissionBase: Cannot access SceneTree in _set_objective_active_in_scene. Node not ready?")
		return

	for node in tree.get_nodes_in_group("mission_objectives"):
		# Ensure node is valid and is the correct type before accessing properties/methods
		if is_instance_valid(node) and node is MissionObjective and node.objective_id == objective_id:
			# Check if state needs changing before calling set_active
			if node.is_active != activate:
				node.set_active(activate)
			return # Found and set (or verified state)

	# Optional: Warning if not found, but might just be in another scene
	# print("MissionNode '%s': Could not find objective '%s' in current scene to set active=%s" % [mission_id, objective_id, activate])

# res://scripts/mission_manager.gd
extends Node

## Orchestrates the active mission, acting as a hub between the mission logic node,
## other managers (Progression, Scene, HUD), and the game world objectives.

# --- Signals Emitted BY MissionManager (for other systems) ---
signal objective_updated(objective_text: String) # For HUDManager
signal request_dialogue(dialog_container: DialogContainer) # For HUDManager
signal report_mission_complete(mission_id: String) # For ProgressionManager (redundant?)
signal report_ability_unlock(ability_name: String) # For ProgressionManager
signal report_key_item_acquired(item_id: String) # For ProgressionManager
signal request_cutscene_animation(anim_name: String, status: bool) # For PlayerAnimation
signal mission_completed(mission_id: String) # For ProgressionManager

# --- Mission Definitions ---
# Maps mission IDs to the script paths for their logic controllers.
const MISSION_DEFINITIONS = {
	"M1_Find_D00D4D": "res://scripts/missions/mission_1.gd",
	# Add future missions here
}

# --- State ---
var current_mission_id: String = ""           # ID of the active mission from ProgressionManager
var active_mission_node: MissionBase = null # Instance of the active mission's controller node
var _scene_to_load_after_outro: String = ""   # Temp storage for scene path while waiting for outro

# --- Global Interaction Vars (Consider moving if not mission-specific) ---
var mission_interactable: Node = null # Target for player interaction action
var cutscene_fall: bool = false       # Player animation state override
var cutscene_walk: bool = false       # Player animation state override
var min_rarity_tier: int = 1          # Scanner config
var max_rarity_tier: int = 5          # Scanner config
var priority_objects = {}             # Scanner config
var exclude_cats: Array = []          # Scanner config

# --- Initialization ---
func _ready() -> void:
	# Ensure required managers are available (check done by GameManager)
	if not ProgressionManager or not SceneManager or not HUDManager:
		push_error("MM: Critical manager dependency missing!")
		set_process(false)
		return

	# Connect to signals FROM other managers
	ProgressionManager.game_loaded.connect(_on_game_loaded_determine_mission, CONNECT_ONE_SHOT)
	SceneManager.scene_loaded.connect(_on_scene_loaded)
	print("MissionManager Ready.")

# --- Mission Lifecycle ---

func _on_game_loaded_determine_mission() -> void:
	print("MM: Game loaded, determining mission.")
	var saved_mission_id = ProgressionManager.get_current_mission_id()
	var saved_mission_state = ProgressionManager.get_mission_save_state(saved_mission_id)

	# Logic to decide which mission to start/resume
	if not saved_mission_id.is_empty() and not ProgressionManager.is_mission_complete(saved_mission_id):
		print("MM: Resuming mission '%s'." % saved_mission_id)
		start_or_resume_mission(saved_mission_id, saved_mission_state)
	elif not ProgressionManager.is_mission_complete("M1_Find_D00D4D"):
		print("MM: No active mission saved or previous mission complete. Starting M1.")
		start_or_resume_mission("M1_Find_D00D4D")
	else:
		print("MM: All known missions complete or no mission to start.")
		objective_updated.emit("No active mission.")


func start_or_resume_mission(mission_id: String, saved_state: Dictionary = {}):
	if not MISSION_DEFINITIONS.has(mission_id):
		push_error("MM: Unknown mission ID: %s" % mission_id)
		return

	# Stop and clean up previous mission node if any
	if is_instance_valid(active_mission_node):
		if active_mission_node.mission_id == mission_id:
			print("MM: Mission %s already active." % mission_id)
			return # Don't restart the same mission
		print("MM: Stopping previous mission: %s" % active_mission_node.mission_id)
		if active_mission_node.get_parent() == self: remove_child(active_mission_node)
		active_mission_node.stop_mission()
		_disconnect_mission_signals(active_mission_node)
		active_mission_node.queue_free()
		active_mission_node = null

	current_mission_id = "" # Clear ID until successful load

	# Load and instantiate the new mission node script
	var mission_script_path = MISSION_DEFINITIONS[mission_id]
	var mission_script = load(mission_script_path) as GDScript
	if not mission_script: push_error("MM: Failed to load mission script: %s" % mission_script_path); return

	active_mission_node = mission_script.new() as MissionBase
	if not active_mission_node: push_error("MM: Failed to instantiate mission node from script: %s" % mission_script_path); return

	# Add the node to the tree (child of MissionManager)
	active_mission_node.name = mission_id # Useful for debugging in remote tree
	add_child(active_mission_node)

	active_mission_node.mission_id = mission_id
	current_mission_id = mission_id # Set ID now that it's loaded
	ProgressionManager.set_current_mission_id(current_mission_id) # Inform PM

	_connect_mission_signals(active_mission_node)

	# Load saved state if provided and method exists
	if not saved_state.is_empty() and active_mission_node.has_method("load_mission_state"):
		active_mission_node.load_mission_state(saved_state)

	# Start the mission logic (sets internal state like current_step_index)
	active_mission_node.start_mission()

	# Important: DO NOT connect objectives or process step here.
	# That happens in _on_scene_loaded after the relevant scene is ready.
	print("MM: Started/Resumed Mission %s. Node created." % mission_id)


## Central handler FOR Objective Triggers - forwards to the active mission node
func handle_objective_trigger(objective_id: String) -> void:
	if is_instance_valid(active_mission_node):
		active_mission_node.handle_objective_trigger(objective_id)
	else:
		print("MM: Received objective trigger '%s' but no active mission node." % objective_id)


# --- Signal Handlers FROM MissionBase Node ---

func _on_mission_request_ui_update(objective_text: String):
	objective_updated.emit(objective_text) # Forward to HUDManager

func _on_mission_report_mission_flag(flag_name: String):
	ProgressionManager.set_flag(flag_name) # Example: Store flag in PM
	print("MM: Mission reported flag: %s" % flag_name)

func _on_mission_report_ability_unlock(ability_name: String):
	ProgressionManager.unlock_ability(ability_name) # Store ability unlock
	report_ability_unlock.emit(ability_name) # Also emit signal if needed elsewhere

func _on_mission_report_key_item_acquired(item_id: String):
	ProgressionManager.acquire_key_item(item_id) # Example: Store item in PM
	report_key_item_acquired.emit(item_id) # Also emit signal

func _on_mission_request_dialogue(dialog_container: DialogContainer):
	request_dialogue.emit(dialog_container) # Forward to HUDManager

func _on_mission_request_cutscene_animation(anim_name: String, status: bool):
	request_cutscene_animation.emit(anim_name, status) # Forward to PlayerAnimation

func _on_mission_completed(mission_id: String):
	print("MM: MissionNode reported mission %s complete." % mission_id)
	ProgressionManager.complete_mission(mission_id) # Mark complete in PM
	mission_completed.emit(mission_id) # Emit signal for other systems

	# Clean up the completed mission node
	if is_instance_valid(active_mission_node) and active_mission_node.mission_id == mission_id:
		if active_mission_node.get_parent() == self: remove_child(active_mission_node)
		_disconnect_mission_signals(active_mission_node)
		active_mission_node.queue_free()
		active_mission_node = null
	current_mission_id = "" # Clear active mission ID

	objective_updated.emit("Mission Complete!") # Update HUD


func _on_mission_request_scene_change_after_outro(next_scene_path: String):
	"""Handles requests from MissionNode to change scene after current scene's outro."""
	print("MM: Received request to change scene to '%s' after current scene outro." % next_scene_path)

	# Store the path for when the outro signal arrives
	_scene_to_load_after_outro = next_scene_path

	# Find the current scene controller node using the group
	var scene_controllers = get_tree().get_nodes_in_group("mission_level_controller")
	if scene_controllers.is_empty():
		push_error("MM: Cannot find node in group 'mission_level_controller' to wait for signal! Changing scene immediately.")
		SceneManager.change_scene(next_scene_path, true)
		_scene_to_load_after_outro = "" # Clear path as we didn't wait
		return

	var scene_controller = scene_controllers[0] # Assume the first one found is correct

	# Check if the scene controller has the expected signal
	if not scene_controller.has_signal("scene_outro_complete"):
		push_error("MM: Node '%s' in group 'mission_level_controller' does not have 'scene_outro_complete' signal! Changing scene immediately." % scene_controller.name)
		SceneManager.change_scene(next_scene_path, true)
		_scene_to_load_after_outro = "" # Clear path
		return

	# Connect the scene's signal TO MM's handler, ONCE per request.
	var callable = Callable(self, "_on_scene_outro_complete_for_change")
	# Attempt connection even if already connected - ONE_SHOT handles redundancy.
	var err = scene_controller.scene_outro_complete.connect(callable, CONNECT_ONE_SHOT | CONNECT_REFERENCE_COUNTED)

	if err == OK:
		print("MM: Now waiting for %s.scene_outro_complete..." % scene_controller.name)
	else:
		# Log error but still attempt scene change as fallback
		push_error("MM: Failed to connect to scene_outro_complete signal! Error: %s. Changing scene immediately." % err)
		SceneManager.change_scene(next_scene_path, true)
		_scene_to_load_after_outro = "" # Clear path


# --- Handler for the scene's signal ---
func _on_scene_outro_complete_for_change():
	"""Called when the scene controller (Crater, Canyon) emits scene_outro_complete."""
	print("MM: Received scene_outro_complete.")

	var scene_to_load = _scene_to_load_after_outro

	# Clear the stored path *immediately*
	_scene_to_load_after_outro = ""

	if not scene_to_load.is_empty():
		print("MM: Outro complete. Calling SceneManager to change scene to %s" % scene_to_load)
		# Call SceneManager to perform the actual transition
		SceneManager.change_scene(scene_to_load, true) # Assume loading screen desired
	else:
		# This indicates the signal fired but MM wasn't expecting it or lost the path
		push_error("MM: Scene outro complete, but no scene path was stored!")


# --- Scene Load Handling ---
func _on_scene_loaded(scene_path: String):
	"""Called AFTER SceneManager finishes loading a new scene."""
	# Reset any pending outro wait if a new scene loaded unexpectedly
	if not _scene_to_load_after_outro.is_empty():
		push_warning("MM: New scene '%s' loaded while waiting for previous scene's outro! Resetting wait state." % scene_path)
		_scene_to_load_after_outro = ""

	if not is_instance_valid(active_mission_node): return # No active mission

	print("MM: Scene loaded: %s. Connecting objectives & processing step." % scene_path)
	_connect_objectives_in_current_scene() # Connect objective triggers
	active_mission_node._process_current_step() # Update mission state/UI/activation for new scene


func _connect_objectives_in_current_scene():
	"""Connects MissionObjective nodes in the current scene to the active mission node."""
	if not is_instance_valid(active_mission_node): return

	var objective_nodes = get_tree().get_nodes_in_group("mission_objectives")
	print("MM: Found %d nodes in 'mission_objectives' group." % objective_nodes.size())
	for node in objective_nodes:
		if node is MissionObjective:
			var callable = Callable(active_mission_node, "handle_objective_trigger")
			# Check if already connected (prevent duplicates if scene reloaded without MM restarting)
			if not node.objective_triggered.is_connected(callable):
				var err = node.objective_triggered.connect(callable)
				if err == OK:
					print("MM: Connected objective '%s' -> %s" % [node.objective_id, active_mission_node.name])
				else:
					push_error("MM: Failed connect objective '%s' -> %s. Err: %s" % [node.objective_id, active_mission_node.name, err])
		# else: print("MM: Node %s is not a MissionObjective" % node.name) # Debug


# --- Signal Connection Helpers ---

func _connect_mission_signals(mission_node: MissionBase):
	"""Connects signals FROM the mission node TO MissionManager handlers."""
	mission_node.request_ui_update.connect(_on_mission_request_ui_update)
	mission_node.report_mission_flag.connect(_on_mission_report_mission_flag)
	mission_node.report_ability_unlock.connect(_on_mission_report_ability_unlock)
	mission_node.report_key_item_acquired.connect(_on_mission_report_key_item_acquired)
	mission_node.request_dialogue.connect(_on_mission_request_dialogue)
	mission_node.request_cutscene_animation.connect(_on_mission_request_cutscene_animation)
	mission_node.mission_completed.connect(_on_mission_completed)
	# Connect the scene change request signal
	mission_node.request_scene_change_after_outro.connect(_on_mission_request_scene_change_after_outro)
	print("MM: Connected signals from %s" % mission_node.name)

func _disconnect_mission_signals(mission_node: MissionBase):
	"""Disconnects signals FROM the mission node TO MissionManager handlers."""
	if mission_node.request_ui_update.is_connected(_on_mission_request_ui_update):
		mission_node.request_ui_update.disconnect(_on_mission_request_ui_update)
	if mission_node.report_mission_flag.is_connected(_on_mission_report_mission_flag):
		mission_node.report_mission_flag.disconnect(_on_mission_report_mission_flag)
	if mission_node.report_ability_unlock.is_connected(_on_mission_report_ability_unlock):
		mission_node.report_ability_unlock.disconnect(_on_mission_report_ability_unlock)
	if mission_node.report_key_item_acquired.is_connected(_on_mission_report_key_item_acquired):
		mission_node.report_key_item_acquired.disconnect(_on_mission_report_key_item_acquired)
	if mission_node.request_dialogue.is_connected(_on_mission_request_dialogue):
		mission_node.request_dialogue.disconnect(_on_mission_request_dialogue)
	if mission_node.request_cutscene_animation.is_connected(_on_mission_request_cutscene_animation):
		mission_node.request_cutscene_animation.disconnect(_on_mission_request_cutscene_animation)
	if mission_node.mission_completed.is_connected(_on_mission_completed):
		mission_node.mission_completed.disconnect(_on_mission_completed)
	# Disconnect the scene change request signal
	if mission_node.request_scene_change_after_outro.is_connected(_on_mission_request_scene_change_after_outro):
		mission_node.request_scene_change_after_outro.disconnect(_on_mission_request_scene_change_after_outro)
	print("MM: Disconnected signals from %s" % mission_node.name)

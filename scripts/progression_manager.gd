# res://scripts/managers/progression_manager.gd
extends Node

## Manages the player's persistent progress through the game story and levels.
## Handles saving and loading core progression data.

# --- Signals ---
signal level_changed(new_level_id: String)
signal ability_unlocked(ability_name: String)
signal mission_completed(mission_id: String) # Emitted when a mission is marked complete here
signal game_loaded # Emitted after load_game finishes OR new game state is initialized

# --- Constants ---
const SAVE_FILE_PATH = "user://snaut_save.json"

# --- Core Progression State ---
var current_level_id: String = "Level1"
var completed_mission_flags: Dictionary = {} # Key: mission_id, Value: true
var unlocked_abilities: Dictionary = {}    # Key: ability_name, Value: true
var npc_relationship_levels: Dictionary = {} # Key: npc_id, Value: int
var current_active_mission_id: String = ""   # ID of the currently active mission
var mission_save_states: Dictionary = {}     # Key: mission_id, Value: mission-specific save data (Dictionary)

# --- Initialization ---
func _ready() -> void:
	print("ProgressionManager Ready. Current Level: ", current_level_id)

# --- Public API ---

func get_current_level() -> String: return current_level_id
func is_mission_complete(mission_id: String) -> bool: return completed_mission_flags.has(mission_id)
func has_ability(ability_name: String) -> bool: return unlocked_abilities.has(ability_name)
func get_npc_relationship(npc_id: String) -> int: return npc_relationship_levels.get(npc_id, 0)
func get_current_mission_id() -> String: return current_active_mission_id
func get_mission_save_state(mission_id: String) -> Dictionary: return mission_save_states.get(mission_id, {})

func set_current_mission_id(mission_id: String):
	if current_active_mission_id != mission_id:
		current_active_mission_id = mission_id
		# Consider saving game automatically here if desired
		# save_game()

func store_mission_save_state(mission_id: String, state_data: Dictionary):
	if mission_id.is_empty(): return
	mission_save_states[mission_id] = state_data
	# Consider saving game automatically here if desired
	# save_game()

# --- State Modification Methods ---

func advance_to_level(new_level_id: String) -> void:
	if current_level_id != new_level_id:
		print("ProgressionManager: Advancing from Level %s to %s" % [current_level_id, new_level_id])
		current_level_id = new_level_id
		level_changed.emit(new_level_id)
		save_game() # Good place for auto-save

func complete_mission(mission_id: String) -> void:
	if mission_id.is_empty(): return
	if not completed_mission_flags.has(mission_id):
		print("ProgressionManager: Completing Mission %s" % mission_id)
		completed_mission_flags[mission_id] = true
		# If this was the active mission, clear it
		if current_active_mission_id == mission_id:
			current_active_mission_id = ""
			# Remove its specific save state? Optional, might be useful later.
			# if mission_save_states.has(mission_id):
			# 	mission_save_states.erase(mission_id)
		mission_completed.emit(mission_id)
		save_game() # Good place for auto-save

func unlock_ability(ability_name: String) -> void:
	if not unlocked_abilities.has(ability_name):
		print("ProgressionManager: Unlocking Ability %s" % ability_name)
		unlocked_abilities[ability_name] = true
		ability_unlocked.emit(ability_name)
		save_game()

func set_npc_relationship(npc_id: String, level: int) -> void:
	level = clamp(level, 0, 5)
	var current_level = get_npc_relationship(npc_id)
	if current_level != level:
		print("ProgressionManager: Setting NPC %s relationship to Level %d" % [npc_id, level])
		npc_relationship_levels[npc_id] = level
		save_game()

# --- Saving and Loading ---

func save_game() -> bool:
	print("ProgressionManager: Attempting to save game...")
	var save_data = {
		"version": 1,
		"level_id": current_level_id,
		"completed_missions": completed_mission_flags, # Consistency: Use same key as loaded
		"abilities": unlocked_abilities,
		"relationships": npc_relationship_levels,
		"active_mission_id": current_active_mission_id,
		"mission_states": mission_save_states,
	}

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if FileAccess.get_open_error() != OK:
		push_error("ProgressionManager: Failed to open save file for writing: %s" % SAVE_FILE_PATH)
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	# file.close() # Not needed with store_string and var scope end

	print("ProgressionManager: Game Saved successfully to %s" % SAVE_FILE_PATH)
	return true


func load_game() -> bool:
	print("ProgressionManager: Attempting to load game...")
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("ProgressionManager: No save file found at %s. Starting new game state." % SAVE_FILE_PATH)
		_initialize_new_game_state()
		game_loaded.emit() # Emit signal even for new game
		return false

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		push_error("ProgressionManager: Failed to open save file for reading: %s" % SAVE_FILE_PATH)
		return false

	var content = file.get_as_text()
	# file.close() # Not needed with get_as_text and var scope end

	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		push_error("ProgressionManager: Failed to parse save file JSON. Error %d at line %d." % [error, json.get_error_line()])
		_initialize_new_game_state() # Load default state on parse error
		game_loaded.emit() # Emit signal even on error
		return false

	var save_data = json.data
	if not save_data is Dictionary:
		push_error("ProgressionManager: Save data root is not a Dictionary.")
		_initialize_new_game_state()
		game_loaded.emit()
		return false

	# --- Data Migration ---
	var save_version = save_data.get("version", 0)
	if save_version < 1:
		push_warning("ProgressionManager: Save file is an older version (%d)." % save_version)
		# Add migration logic here later if needed

	# --- Load Data ---
	current_level_id = str(save_data.get("level_id", "Level1"))
	completed_mission_flags = save_data.get("completed_missions", {}) if save_data.get("completed_missions", {}) is Dictionary else {}
	unlocked_abilities = save_data.get("abilities", {}) if save_data.get("abilities", {}) is Dictionary else {}
	npc_relationship_levels = save_data.get("relationships", {}) if save_data.get("relationships", {}) is Dictionary else {}
	current_active_mission_id = str(save_data.get("active_mission_id", ""))
	mission_save_states = save_data.get("mission_states", {}) if save_data.get("mission_states", {}) is Dictionary else {}

	print("ProgressionManager: Game Loaded. Level: %s, Active Mission: '%s'" % [current_level_id, current_active_mission_id])
	game_loaded.emit()
	return true

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

func set_flag(flag_name: String) -> void:
	# Placeholder for setting arbitrary flags if needed later
	print("ProgressionManager: Flag '%s' set (Not currently saved)." % flag_name)
	pass

func acquire_key_item(item_id: String) -> void:
	# Placeholder for key item system
	print("ProgressionManager: Key item '%s' acquired (Not currently saved)." % item_id)
	pass

# --- Internal Helpers ---

func _initialize_new_game_state() -> void:
	print("ProgressionManager: Initializing new game state.")
	current_level_id = "Level1"
	completed_mission_flags = {}
	unlocked_abilities = {}
	npc_relationship_levels = {}
	current_active_mission_id = ""
	mission_save_states = {}

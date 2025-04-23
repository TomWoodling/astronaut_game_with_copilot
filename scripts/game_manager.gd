# res://scripts/managers/game_manager.gd
extends Node

## Manages the overall game state, gameplay state, pausing, and global cancel input.
## Integrates with ProgressionManager for loading/saving core progress.

# --- Signals ---
signal game_state_changed(previous_state: GameState, new_state: GameState)
signal gameplay_state_changed(previous_state: GameplayState, new_state: GameplayState)
signal cancel_action_requested

# --- Enums ---
enum GameState {
	MAIN_MENU, # Game is in the main menu screen
	LOADING,   # Game is loading assets or a new scene (or save game)
	PLAYING,   # Player is actively playing the game
	PAUSED,    # Game is paused (time scale = 0)
	GAME_OVER  # Game over screen is displayed
}

enum GameplayState {
	NORMAL,
	SCANNING,
	DIALOGUE,
	STUNNED,
	CUTSCENE,
	POPUP
}

# --- State Variables ---
var _current_game_state: GameState = GameState.MAIN_MENU # Start in Main Menu typically
var _current_gameplay_state: GameplayState = GameplayState.NORMAL

# --- Properties ---
var player: CharacterBody3D = null # Still set externally (e.g., by world setup)

# --- Dependencies ---
# Access singletons directly after validation in _ready
var ProgManager: ProgressionManager = null
var ScnManager: SceneManager = null

# --- Initialization ---
func _ready() -> void:
	# Ensure game is not paused on editor start/restart
	get_tree().paused = false
	process_mode = PROCESS_MODE_ALWAYS

	# --- ONE-TIME VALIDATION of Dependencies ---
	ProgManager = get_node_or_null("/root/ProgressionManager")
	if not ProgManager:
		push_error("GameManager CRITICAL FAIL: ProgressionManager singleton not found.")
		# If ProgressionManager is critical, maybe quit or show an error?
		# get_tree().quit()
		set_process(false) # Disable further processing
		return

	ScnManager = get_node_or_null("/root/SceneManager")
	if not ScnManager:
		push_error("GameManager CRITICAL FAIL: SceneManager singleton not found.")
		set_process(false)
		return

	print("GameManager Ready. Initial GameState: ", GameState.keys()[_current_game_state])


# --- Input Handling (No changes needed here) ---
func _input(event: InputEvent) -> void:
	# Handle the global cancel action (Esc key)
	if event.is_action_pressed("ui_cancel"):
		match _current_game_state:
			GameState.PLAYING:
				match _current_gameplay_state:
					GameplayState.NORMAL, GameplayState.SCANNING:
						pause_game()
						get_viewport().set_input_as_handled()
					GameplayState.DIALOGUE, GameplayState.POPUP:
						cancel_action_requested.emit() # Let Encounter/Mission handle it
						get_viewport().set_input_as_handled()
					GameplayState.STUNNED:
						pass
			GameState.PAUSED:
				resume_game()
				get_viewport().set_input_as_handled()
			GameState.MAIN_MENU, GameState.GAME_OVER:
				cancel_action_requested.emit() # For UI back actions
				get_viewport().set_input_as_handled()
			GameState.LOADING:
				pass

# --- Public Methods ---

## Changes the overall game state (MainMenu, Loading, Playing, Paused).
func change_game_state(new_state: GameState) -> void:
	if _current_game_state == new_state:
		return

	var previous_state: GameState = _current_game_state
	_current_game_state = new_state
	print("Game State Changed: %s -> %s" % [GameState.keys()[previous_state], GameState.keys()[new_state]])

	match _current_game_state:
		GameState.PLAYING:
			if previous_state == GameState.PAUSED:
				# Resuming game
				get_tree().paused = false
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				# Optionally hide pause menu via HUDManager signal
			elif previous_state == GameState.MAIN_MENU or previous_state == GameState.LOADING:
				# Just started playing (after loading finished)
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) # Ensure mouse is captured
				# Ensure time scale is correct if loading didn't reset it
				get_tree().paused = false

		GameState.PAUSED:
			get_tree().paused = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			# Optionally show pause menu via HUDManager signal

		GameState.LOADING:
			# Potentially show a loading indicator via HUDManager
			# Ensure game isn't paused during loading unless intended
			get_tree().paused = false # Usually false during loading

		GameState.MAIN_MENU:
			# Ensure game isn't paused, show cursor
			get_tree().paused = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		_: # Any other state
			if get_tree().paused: # General check to unpause if leaving Paused
				get_tree().paused = false


	game_state_changed.emit(previous_state, new_state)


## Called by UI actions (e.g., clicking "New Game" or "Continue")
func start_new_game() -> void:
	print("GameManager: Starting New Game...")
	change_game_state(GameState.LOADING)
	ProgManager._initialize_new_game_state()

	# Use SceneManager to load the initial scene
	# Determine the very first scene (e.g., Prologue or Level 1)
	var initial_scene = _get_scene_path_for_level("Level1") # Or "Prologue"
	ScnManager.change_scene(initial_scene, true) # Show loading screen
	# SceneManager will call finish_loading_game() when done


func load_saved_game() -> void:
	print("GameManager: Loading Saved Game...")
	if not ProgManager.has_save_file():
		start_new_game()
		return

	change_game_state(GameState.LOADING)
	var load_success = ProgManager.load_game()
	if not load_success:
		start_new_game()
		return

	var scene_to_load = _get_scene_path_for_level(ProgManager.get_current_level())
	print("GameManager: Loading scene for level %s: %s" % [ProgManager.get_current_level(), scene_to_load])

	# Use SceneManager
	ScnManager.change_scene(scene_to_load, true) # Show loading screen
	# SceneManager will call finish_loading_game() when done


## Called by SceneManager after the game scene is loaded and ready
func finish_loading_game() -> void:
	# Ensure we are in the loading state before transitioning to playing
	if _current_game_state == GameState.LOADING:
		print("GameManager: Scene loaded, transitioning to Playing state.")
		change_game_state(GameState.PLAYING)
	else:
		push_warning("GameManager: finish_loading_game called when not in LOADING state (%s)" % GameState.keys()[_current_game_state])


## Changes the player's interaction state during gameplay
func set_gameplay_state(new_state: GameplayState) -> void:
	# ... (no changes needed in this function itself) ...
	if _current_gameplay_state == new_state:
		return
	var previous_state: GameplayState = _current_gameplay_state
	_current_gameplay_state = new_state
	var prev_key = GameplayState.keys()[previous_state] if previous_state >= 0 and previous_state < GameplayState.size() else "INVALID"
	var new_key = GameplayState.keys()[new_state] if new_state >= 0 and new_state < GameplayState.size() else "INVALID"
	print("Gameplay State Changed: %s -> %s" % [prev_key, new_key])
	gameplay_state_changed.emit(previous_state, new_state)


## Pauses the game.
func pause_game() -> void:
	if _current_game_state == GameState.PLAYING and _current_gameplay_state != GameplayState.STUNNED:
		change_game_state(GameState.PAUSED)


## Resumes the game from a paused state.
func resume_game() -> void:
	if _current_game_state == GameState.PAUSED:
		change_game_state(GameState.PLAYING) # change_game_state handles unpausing


## Helper Methods / Getters (No changes needed)
func is_player_controllable() -> bool:
	return _current_game_state == GameState.PLAYING and _current_gameplay_state == GameplayState.NORMAL

func get_current_game_state() -> GameState:
	return _current_game_state

func get_current_gameplay_state() -> GameplayState:
	return _current_gameplay_state

# --- Internal Helpers ---

func _get_scene_path_for_level(level_id: String) -> String:
	# Map level IDs from ProgressionManager to actual scene file paths
	# CRITICAL:This needs to be maintained as you create levels.
	match level_id:
		"Prologue": return "res://scenes/levels/prologue.tscn" # Example
		"Level1": return "res://scenes/levels/level_1_world.tscn" # Example
		"Level2": return "res://scenes/levels/level_2_world.tscn" # Example
		"Level3": return "res://scenes/levels/level_3_world.tscn" # Example
		# Add cases for Level 4, 5, 6, 7...
		_:
			push_error("GameManager: Unknown level_id '%s'. Cannot determine scene path. Defaulting to Level 1." % level_id)
			return "res://scenes/levels/level_1_world.tscn" # Fallback


# --- Signal Handlers (Optional) ---

# func _on_game_loaded():
#    print("GameManager notified that ProgressionManager finished loading.")
#    # Any actions needed immediately after load completes?

# res://scenes/ui/MainMenu.gd
extends Node # Or Control if attached to root

# Assign buttons in the editor
@export var start_button: Button
@export var quit_button: Button # Optional

func _ready() -> void:
	# --- Basic Validation ---
	if not start_button:
		push_error("MainMenu: StartButton not assigned in the editor!")
		return # Don't connect signals if button is missing
	# --- End Validation ---

	# Ensure cursor is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)

	if quit_button: # Only connect if the quit button exists
		quit_button.pressed.connect(_on_quit_button_pressed)

	# Tell GameManager we are in the main menu state
	# Check GameManager exists - crucial on initial load
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
	else:
		# This case *shouldn't* happen if Autoload order is correct (GameManager first)
		push_error("MainMenu: GameManager Autoload not ready!")


func _on_start_button_pressed() -> void:
	print("Start button pressed - initiating game start...")
	# Disable button to prevent double clicks during transition
	if start_button: start_button.disabled = true
	if quit_button: quit_button.disabled = true

	# 1. Tell GameManager we are loading
	GameManager.change_game_state(GameManager.GameState.LOADING)

	# 2. Initiate scene change (use deferred for safety)
	#call_deferred("_change_to_world_scene")
	call_deferred("_change_to_mission_scene")


func _change_to_world_scene() -> void:
	# The actual scene change. Error handling is good practice.
	var err = get_tree().change_scene_to_file("res://scenes/world.tscn")
	if err != OK:
		push_error("MainMenu: Failed to change scene to world.tscn! Error code: %s" % err)
		# Re-enable buttons if change fails
		if start_button: start_button.disabled = false
		if quit_button: quit_button.disabled = false
		# Optionally revert game state or show error message
		if GameManager: GameManager.change_game_state(GameManager.GameState.MAIN_MENU)

func _change_to_mission_scene() -> void:
	# Using the legit scene manager to queue up our vids:
	start_multi_part_intro()
	ProgressionManager.load_game()

func _on_quit_button_pressed() -> void:
	print("Quit button pressed.")
	get_tree().quit() # Quit the application

func start_multi_part_intro():
	print("Queueing intro sequence...")
	# Video 1: No pre-title, but has a post-title
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/prologue_1.ogv",
		"", # No pre-title text
		"Experience the wonder of the cosmos, they said...", # Post-title text shown after video 1
		3.0 # Duration for the post-title card
	)
	
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/crypto.ogv",
		"But sometimes I wonder what I'm doing out here, running around after Chads...", # No pre-title text
		"Oh no my crypto has crashed, Snaut...", # Post-title text shown after video 1
		3.0 # Duration for the post-title card
	)

	# Video 3: Has a pre-title (shown after video 1's post-title fades out), no post-title
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/message_from_x.ogv",
		"...go wait in the cargo hold while we talk to Mr X, Snaut!", # Pre-title text shown before video 2
		"He'll put a dyson sphere around a star to mine the last $kipcoin! Yeah, that seems legit...", # No post-title text
		3.0 # Duration for the pre-title card
	)
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/explo2.ogv",
		"But sometimes you find out a dying star is really an unstable planet!", # Pre-title text shown before video 2
		"", # No post-title text
		3.0 # Duration for the pre-title card
	)
	SceneManager.queue_cutscene(
		"res://assets/cutscenes/explo1.ogv",
		"Even if nobody wants to hear about it.", # Pre-title text shown before video 2
		"And now we crashed for real...", # No post-title text
		3.0 # Duration for the pre-title card
	)

	# The first video will start playing automatically (if nothing else was playing)
	# The rest will play sequentially after the previous one finishes.
	print("Intro sequence queued.")

	# Optional: Wait for the entire queue to finish
	await SceneManager.cutscene_queue_completed
	print("Entire intro sequence finished!")
	# Now load the next scene, etc.
	SceneManager.change_scene("res://scenes/missions/mission1/mission1_crater.tscn")

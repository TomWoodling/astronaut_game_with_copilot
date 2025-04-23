extends Popup
class_name PopupUI

signal popup_closed(confirmed)
signal minigame_completed(success) # Consider removing if only using succeeded/failed
signal confirm_pressed
signal cancel_pressed

@export var title_text : String = "Information"
@export var content_text : String = "This is popup content."
# No longer export has_minigame, we determine it based on provided scene
# @export var has_minigame : bool = false

# Store the scene to be instantiated later
var minigame_scene_to_load: PackedScene = null
var minigame_instance = null
var has_minigame : bool = false # Internal flag set by initialize

@onready var title_label : Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var content_label : Label = $Panel/MarginContainer/VBoxContainer/ContentLabel
@onready var confirm_button : Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton
@onready var cancel_button : Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CancelButton
@onready var close_button : Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/CloseButton
@onready var minigame_window : Panel = $MinigameWindow
@onready var _previous_mouse_mode: Input.MouseMode

# --- Initialization Step 1: Receive the Scene ---
## Stores the minigame scene path. Called *before* _ready().
func initialize(minigame_scene: PackedScene = null):
	minigame_scene_to_load = minigame_scene
	if minigame_scene_to_load != null:
		has_minigame = true
	else:
		has_minigame = false
		# We can hide the window placeholder early if no scene is provided
		if is_inside_tree() and minigame_window: # Safety check if called late
			minigame_window.visible = false
		# else: _ready will handle hiding it

# --- Initialization Step 2: Setup when Ready ---
func _ready():
	title_label.text = title_text
	content_label.text = content_text

	# Default Button visibility
	close_button.visible = false
	cancel_button.visible = false
	confirm_button.visible = true # Start with confirm visible

	# Connect button signals
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_button.pressed.connect(_on_close_pressed)
	# Mouse handling
	_previous_mouse_mode = Input.get_mouse_mode() # Store current mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Make mouse visible for UI
	# --- Instantiate and Setup Minigame (if provided) ---
	if has_minigame and minigame_scene_to_load:
		print("PopupUI: Minigame scene provided, instantiating...")
		# Now minigame_window is guaranteed to be ready because we are in _ready()
		minigame_instance = minigame_scene_to_load.instantiate()
		if minigame_instance:
			minigame_window.add_child(minigame_instance)
			minigame_window.visible = true # Ensure window is visible

			# Connect to minigame signals AFTER instantiation and adding
			if minigame_instance.has_signal("minigame_succeeded"):
				if not minigame_instance.minigame_succeeded.is_connected(_on_minigame_success):
					minigame_instance.minigame_succeeded.connect(_on_minigame_success)
			else:
				push_warning("PopupUI: Minigame instance lacks 'minigame_succeeded' signal.")

			if minigame_instance.has_signal("minigame_failed"):
				if not minigame_instance.minigame_failed.is_connected(_on_minigame_failure):
					minigame_instance.minigame_failed.connect(_on_minigame_failure)
			else:
				push_warning("PopupUI: Minigame instance lacks 'minigame_failed' signal.")

			# --- Minigame Requires Interaction ---
			# Hide confirm/close initially, minigame outcome will show them
			confirm_button.visible = false
			close_button.visible = false
			cancel_button.visible = false # Or maybe keep cancel visible? Depends on design.

			# Start the minigame if it has a start method
			if minigame_instance.has_method("_game_start"):
				minigame_instance._game_start()
			else:
				push_warning("PopupUI: Minigame instance lacks '_game_start()' method.")

		else:
			push_error("PopupUI: Failed to instantiate minigame scene!")
			minigame_window.visible = false
			has_minigame = false # Treat as if no minigame
	else:
		# Hide the minigame window if no minigame was provided or intended
		minigame_window.visible = false
	# --- End Minigame Setup ---

	# Take focus (do this after potentially hiding/showing buttons)
	if confirm_button.visible:
		confirm_button.grab_focus()
	elif cancel_button.visible: # Example fallback focus
		cancel_button.grab_focus()
	# Else: Minigame might handle its own focus

	# Pause game (optional)
	get_tree().paused = true

	# Make sure this UI processes while paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_minigame_success():
	print("PopupUI: Minigame Success reported.")
	# Minigame succeeded, show the close button and success message
	confirm_button.visible = false
	cancel_button.visible = false
	close_button.visible = true
	close_button.grab_focus()
	emit_signal("minigame_completed", true) # Let the launcher know
	_set_content_label("Success! The system responded.") # Example success message
	# No longer need confirm_pressed logic here for success

func _on_minigame_failure():
	print("PopupUI: Minigame Failure reported.")
	# Minigame failed, show confirm button to allow retry, update message
	cancel_button.visible = false
	close_button.visible = false
	confirm_button.visible = true # Show confirm to retry/acknowledge
	confirm_button.text = "Try Again" # Change button text maybe?
	confirm_button.grab_focus()
	# Don't emit minigame_completed(false) yet, maybe they retry
	_set_content_label("Hmm, that wasn't quite right. Try again?")
	# No longer need confirm_pressed logic here for failure

func _on_confirm_pressed():
	print("PopupUI: Confirm pressed.")
	emit_signal("confirm_pressed") # Still useful for non-minigame popups or maybe specific actions

	# If we are in a "failed minigame" state, re-trigger the minigame start
	if has_minigame and minigame_instance and minigame_instance.has_method("_game_start"):
		# Hide button again, let minigame logic take over
		confirm_button.visible = false
		minigame_instance._game_start()
		# Optionally reset label text
		# _set_content_label("Minigame instructions...")
	# else:
		# Normal confirm action (if needed for other popup types)
		# _close_popup() # Maybe default action is just close?

func _on_cancel_pressed():
	print("PopupUI: Cancel pressed.")
	emit_signal("cancel_pressed")
	# Typically closes the popup without confirmation
	_close_popup(false) # Pass false for cancelled

func _on_close_pressed():
	print("PopupUI: Close pressed.")
	# This button usually appears after success or for info-only popups
	_close_popup(true) # Pass true for confirmed/closed normally

func _close_popup(confirmed_state: bool = true): # Add parameter to track how it was closed
	# Unpause game (if it was paused)
	get_tree().paused = false
	Input.set_mouse_mode(_previous_mouse_mode) # Restore mode before popup
	emit_signal("popup_closed", confirmed_state) # Signal how it closed
	# Remove this popup
	queue_free()

# Optional: Handle escape key to cancel
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Only trigger cancel if the cancel button is actually an option currently
		if cancel_button.visible and not cancel_button.disabled:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()
		# If cancel isn't visible, maybe Esc maps to Close if that's visible?
		elif close_button.visible and not close_button.disabled:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
		# Add other escape behaviours if needed

func _set_content_label(new_text:String):
	content_label.text = new_text

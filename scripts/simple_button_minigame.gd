# simple_button_minigame.gd
extends Control
class_name SimpleButtonMinigame

signal minigame_succeeded
signal minigame_failed

@onready var green_button : Button = $ButtonContainer/GreenButton
@onready var red_button : Button = $ButtonContainer/RedButton

func _ready():
	# Start disabled until _game_start is called
	green_button.disabled = true
	red_button.disabled = true

func _game_start():
	print("Minigame: Starting game, enabling buttons.") # Debug
	# Enable buttons
	green_button.disabled = false
	red_button.disabled = false
	# Connect button signals if not already connected (safety check)
	if not green_button.pressed.is_connected(_on_green_button_pressed):
		green_button.pressed.connect(_on_green_button_pressed)
	if not red_button.pressed.is_connected(_on_red_button_pressed):
		red_button.pressed.connect(_on_red_button_pressed)
	# Optional: Grab focus for the green button initially?
	green_button.grab_focus()

func _game_stop():
	print("Minigame: Stopping game, disabling buttons.") # Debug
	# Disconnect button signals (important to prevent leaks if reused)
	if green_button.pressed.is_connected(_on_green_button_pressed):
		green_button.pressed.disconnect(_on_green_button_pressed)
	if red_button.pressed.is_connected(_on_red_button_pressed):
		red_button.pressed.disconnect(_on_red_button_pressed)
	# --- Disable buttons visually ---
	green_button.disabled = true
	red_button.disabled = true
	# --- End Disable ---

func _on_green_button_pressed():
	print("Minigame: Green button pressed.") # Debug
	emit_signal("minigame_succeeded")
	_game_stop() # Stop/disable immediately

func _on_red_button_pressed():
	print("Minigame: Red button pressed.") # Debug
	emit_signal("minigame_failed")
	_game_stop() # Stop/disable immediately

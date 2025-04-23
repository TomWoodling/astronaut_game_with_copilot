# res://scripts/ui/dialog_display.gd
# Assumes this script is attached to the root Control node of DialogDisplay.tscn
# which also has the HUDElement script attached or inherits from it.

extends HUDElement

signal dialog_completed
signal dialog_advanced(current_index: int)
signal mood_changed(mood: String)

@export var speaker_label: Label
@export var text_label: Label
# @export var dialog_panel: Panel # Panel might be the root node itself
@export var character_display_time: float = 0.03

@onready var next_indicator: TextureRect = $TextureRect
var current_dialog: DialogContainer # No type hint needed if DialogContainer isn't a class_name
var current_index: int = 0
var is_text_revealing: bool = false
var dialog_text: String = ""
var revealed_text: String = ""
var dialog_tween: Tween

# HUDElement's _ready() handles initial hiding and transparency.
# No need for custom _ready() hiding logic here.

func _input(event) -> void:
	# Rely on HUDElement's 'visible' and 'modulate.a' state
	if not is_fully_visible(): # Use HUDElement's check
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_advance_dialog()
		get_viewport().set_input_as_handled() # Prevent click-through
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_advance_dialog()
		get_viewport().set_input_as_handled() # Prevent event bubbling

func start_dialog(dialog) -> void: # Removed type hint
	if not dialog or dialog.dialog_entries.size() == 0:
		push_warning("DialogDisplay: Invalid or empty dialog provided.")
		return

	current_dialog = dialog
	current_index = 0

	show_element() # Use HUDElement's method to fade in
	display_current_entry()

func display_current_entry() -> void:
	# Kill any previous text reveal tween
	if dialog_tween and dialog_tween.is_valid():
		dialog_tween.kill()

	var entry = current_dialog.get_entry(current_index)
	if not entry:
		complete_dialog()
		return

	# Signal mood change
	emit_signal("mood_changed", entry.mood)

	# Setup display
	speaker_label.text = entry.speaker if entry.speaker else ""
	speaker_label.visible = not entry.speaker.is_empty()

	# Start text reveal animation
	dialog_text = entry.text
	revealed_text = ""
	text_label.text = "" # Clear previous text immediately
	next_indicator.visible = false

	# Start revealing text
	is_text_revealing = true
	reveal_text()

func reveal_text() -> void:
	# Using a SceneTreeTween for text reveal
	dialog_tween = get_tree().create_tween()
	dialog_tween.set_parallel(false) # Process steps sequentially

	var current_revealed_length := 0
	while current_revealed_length < dialog_text.length():
		# Add callback to update text
		dialog_tween.tween_callback(func():
			# Check if the node is still valid before updating
			if not is_instance_valid(self) or not is_instance_valid(text_label): return
			revealed_text += dialog_text[revealed_text.length()]
			text_label.text = revealed_text
		)
		# Wait for character display time
		dialog_tween.tween_interval(character_display_time)
		current_revealed_length += 1

	# When all characters are revealed
	dialog_tween.tween_callback(func():
		if not is_instance_valid(self) or not is_instance_valid(next_indicator): return
		is_text_revealing = false
		next_indicator.visible = true
		dialog_tween = null # Clear finished tween reference
	).set_delay(0.01) # Tiny delay ensures it runs after the last char reveal

	dialog_tween.play()

func _on_advance_dialog() -> void:
	# If text is still revealing, show all text immediately
	if is_text_revealing:
		if dialog_tween and dialog_tween.is_valid():
			dialog_tween.kill() # Stop the reveal tween
			dialog_tween = null
		text_label.text = dialog_text
		revealed_text = dialog_text
		is_text_revealing = false
		next_indicator.visible = true
		return

	# Advance to next dialog entry
	current_index += 1
	emit_signal("dialog_advanced", current_index)

	if current_index >= current_dialog.dialog_entries.size():
		complete_dialog()
	else:
		display_current_entry()

func complete_dialog() -> void:
	hide_element() # Use HUDElement's method to fade out
	emit_signal("dialog_completed")

	# Reset state *after* starting hide animation
	current_dialog = null
	current_index = 0
	is_text_revealing = false
	# Optionally clear labels immediately or let them fade with the panel
	# text_label.text = ""
	# speaker_label.text = ""
	# next_indicator.visible = false

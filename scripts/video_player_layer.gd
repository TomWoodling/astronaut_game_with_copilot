# res://scripts/ui/video_player.gd
extends CanvasLayer
class_name VideoPlayerLayer

## Plays video streams, handles title cards, skipping, and signals completion.
## Simplified version without pause/resume functionality.

signal playback_finished # Emitted when video (and optional end title) completes naturally
signal playback_skipped  # Emitted when the user skips the video or title card

# --- Node References ---
@onready var player: VideoStreamPlayer = $Player
@onready var title_card_panel: Control = $TitleCardPanel
@onready var title_label: Label = $TitleCardPanel/TitleLabel
@onready var skip_prompt_label: Label = $SkipPromptLabel
@onready var background: ColorRect = $Background # Optional

# --- Configuration ---
@export var default_skip_action: StringName = &"ui_accept"
@export var title_card_fade_duration: float = 0.3

# --- State ---
enum State { IDLE, SHOWING_PRE_TITLE, PLAYING, SHOWING_POST_TITLE, FINISHED }
var _current_state: State = State.IDLE
var _video_stream: VideoStream = null
var _pre_title_text: String = ""
var _post_title_text: String = ""
var _title_display_duration: float = 3.0
var _active_tween: Tween = null
var _skip_action_override: StringName = &""


# --- Initialization ---
func _ready() -> void:
	visible = false
	player.stream = null
	player.autoplay = false # Ensure we control play manually
	player.stop()          # Ensure player state is stopped initially
	title_card_panel.modulate.a = 0.0
	title_card_panel.visible = false
	skip_prompt_label.visible = false

	player.finished.connect(_on_video_playback_finished)

# --- Input Handling ---
func _unhandled_input(event: InputEvent) -> void:
	if visible and _current_state != State.IDLE and _current_state != State.FINISHED:
		var action_to_check = default_skip_action
		if _skip_action_override != &"":
			action_to_check = _skip_action_override

		if event.is_action_pressed(action_to_check):
			get_viewport().set_input_as_handled()
			skip_playback()


# --- Public API ---

## Starts the video playback sequence.
func play_sequence(stream: VideoStream, pre_title: String = "", post_title: String = "", title_duration: float = 3.0, skip_action: StringName = &"") -> void:
	if not is_instance_valid(player):
		push_error("VideoPlayerLayer: Player node is not valid!")
		return
	if not stream:
		push_error("VideoPlayerLayer: Provided video stream is null!")
		_cleanup_and_finish(false)
		return

	_kill_existing_tween()

	_video_stream = stream
	_pre_title_text = pre_title
	_post_title_text = post_title
	_title_display_duration = title_duration
	_skip_action_override = skip_action

	# Reset player state
	player.stop() # Ensure player is stopped before changing stream
	player.stream = _video_stream
	# No need to set 'paused' here as we are not pausing/resuming

	visible = true
	if is_instance_valid(background):
		background.visible = true

	if not _pre_title_text.is_empty():
		_show_title_card(_pre_title_text, State.SHOWING_PRE_TITLE)
	else:
		_start_video_playback()

## Stops playback immediately and signals skipped.
func skip_playback() -> void:
	if _current_state == State.FINISHED: return

	print("VideoPlayerLayer: Playback skipped.")
	_cleanup_and_finish(true) # True indicates it was skipped


# --- Internal Logic ---

func _show_title_card(text: String, next_state_after_display: State) -> void:
	_current_state = next_state_after_display

	title_label.text = text
	title_card_panel.modulate.a = 0.0
	title_card_panel.visible = true
	skip_prompt_label.visible = true

	_kill_existing_tween()
	_active_tween = create_tween().set_parallel(false)

	_active_tween.tween_property(title_card_panel, "modulate:a", 1.0, title_card_fade_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(_title_display_duration)
	_active_tween.tween_property(title_card_panel, "modulate:a", 0.0, title_card_fade_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_on_title_card_finished)
	_active_tween.play()


func _on_title_card_finished() -> void:
	title_card_panel.visible = false
	_active_tween = null

	if _current_state == State.SHOWING_PRE_TITLE:
		_start_video_playback()
	elif _current_state == State.SHOWING_POST_TITLE:
		_cleanup_and_finish(false)


func _start_video_playback() -> void:
	if not is_instance_valid(player) or not player.stream:
		push_warning("VideoPlayerLayer: Cannot start playback, player or stream invalid.")
		_cleanup_and_finish(false)
		return

	_current_state = State.PLAYING
	title_card_panel.visible = false
	skip_prompt_label.visible = true

	player.play() # Use the documented play() method
	print("VideoPlayerLayer: Starting video playback.")


func _on_video_playback_finished() -> void:
	# Note: VideoStreamPlayer.finished is emitted when the stream ends.
	if _current_state != State.PLAYING:
		return # Avoid issues if skipped right at the end

	print("VideoPlayerLayer: Video stream finished.")
	skip_prompt_label.visible = false # Hide skip prompt after video ends

	if not _post_title_text.is_empty():
		_show_title_card(_post_title_text, State.SHOWING_POST_TITLE)
	else:
		_cleanup_and_finish(false)


func _cleanup_and_finish(was_skipped: bool) -> void:
	print("VideoPlayerLayer: Cleaning up. Skipped: %s" % was_skipped)
	_current_state = State.FINISHED
	_kill_existing_tween()

	if is_instance_valid(player):
		player.stop()         # Use the documented stop() method
		player.stream = null

	visible = false
	title_card_panel.visible = false
	skip_prompt_label.visible = false
	if is_instance_valid(background):
		background.visible = false

	_video_stream = null
	_pre_title_text = ""
	_post_title_text = ""
	_skip_action_override = &""

	if was_skipped:
		emit_signal("playback_skipped")
	else:
		emit_signal("playback_finished")


func _kill_existing_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

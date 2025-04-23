# res://scripts/managers/scene_manager.gd
extends Node

## Handles loading scenes and managing transitions, including loading screens and queued cutscenes.

# --- Exports ---
@export var loading_screen_scene: PackedScene
@export var video_player_scene: PackedScene

# --- State ---
var current_loading_screen_instance: CanvasLayer = null
var current_video_player_instance: VideoPlayerLayer = null
var is_changing_scene: bool = false
var is_playing_cutscene: bool = false # Flag indicating *any* cutscene (single or queued) is active
var _cutscene_queue: Array[Dictionary] = []

# --- Dependencies ---
var GmManager: GameManager = null # Initialized in _ready

# --- Signals ---
signal single_cutscene_finished
signal single_cutscene_skipped
signal cutscene_queue_item_finished(data: Dictionary)
signal cutscene_queue_item_skipped(data: Dictionary)
signal cutscene_queue_completed
signal scene_loaded(scene_path: String) # Emitted AFTER change_scene completes

# --- Initialization ---
func _ready() -> void:
	# Ensure critical resources are assigned
	if not loading_screen_scene:
		push_error("SceneManager CRITICAL FAIL: Loading Screen Scene not assigned!")
		set_process(false); return
	if not video_player_scene:
		push_error("SceneManager CRITICAL FAIL: Video Player Scene not assigned!")
		set_process(false); return

	GmManager = get_node_or_null("/root/GameManager")
	if not GmManager:
		push_error("SceneManager CRITICAL FAIL: GameManager singleton not found.")
		set_process(false); return

	print("SceneManager Ready.")


# --- Public API ---

func change_scene(scene_path: String, show_loading: bool = true) -> void:
	if is_changing_scene or is_playing_cutscene:
		push_warning("SceneManager: Busy (changing scene or playing cutscene), request for '%s' ignored." % scene_path)
		return

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("SceneManager: Invalid scene path provided: '%s'" % scene_path)
		return

	is_changing_scene = true
	print("SceneManager: Changing scene to %s" % scene_path)

	# Set game state BEFORE showing loading screen
	if GmManager: GmManager.change_game_state(GameManager.GameState.LOADING)

	if show_loading:
		_show_loading_screen()
		# Yield one frame to ensure loading screen renders before potential blocking
		await get_tree().process_frame

	# --- Perform Scene Change ---
	var error = get_tree().change_scene_to_file(scene_path)
	# --- Scene Change Finished ---

	if error != OK:
		push_error("SceneManager: Failed to change scene to '%s'. Error code: %d" % [scene_path, error])
		if show_loading: _hide_loading_screen()
		is_changing_scene = false
		# Optionally revert game state?
		if GmManager: GmManager.change_game_state(GameManager.GameState.MAIN_MENU) # Example revert
		return

	# Yield another frame AFTER change_scene_to_file to allow the new scene's _ready() to execute
	await get_tree().process_frame

	# Notify GameManager AFTER the new scene's _ready has likely run
	if GmManager:
		GmManager.finish_loading_game() # This should transition GameState to PLAYING
	else:
		push_warning("SceneManager: GameManager not found after scene change.")

	# Hide loading screen AFTER new scene is ready and game state is PLAYING
	if show_loading:
		_hide_loading_screen()

	is_changing_scene = false
	print("SceneManager: Scene change to %s complete." % scene_path)
	# Emit signal AFTER everything is done
	scene_loaded.emit(scene_path)


func play_cutscene(video_path: String, pre_title: String = "", post_title: String = "", title_duration: float = 3.0, skip_action: StringName = &""):
	# ... (Implementation remains the same as provided) ...
	if is_changing_scene or is_playing_cutscene: push_warning("SceneManager: Busy, cannot play single cutscene."); return
	var cutscene_data = {"path": video_path, "pre_title": pre_title, "post_title": post_title, "title_duration": title_duration, "skip_action": skip_action, "is_queued": false}
	if not _validate_and_start_playback(cutscene_data): push_error("SceneManager: Failed to start single cutscene.")


func queue_cutscene(video_path: String, pre_title: String = "", post_title: String = "", title_duration: float = 3.0, skip_action: StringName = &""):
	# ... (Implementation remains the same as provided) ...
	if not video_player_scene: push_error("SceneManager: Cannot queue, video_player_scene not set."); return
	if not ResourceLoader.exists(video_path) or not (video_path.ends_with(".ogv") or video_path.ends_with(".webm")): push_error("SceneManager: Invalid video path for queue: '%s'" % video_path); return
	var cutscene_data = {"path": video_path, "pre_title": pre_title, "post_title": post_title, "title_duration": title_duration, "skip_action": skip_action, "is_queued": true}
	_cutscene_queue.append(cutscene_data)
	print("SceneManager: Queued cutscene %s (Queue size: %d)" % [video_path, _cutscene_queue.size()])
	if not is_playing_cutscene and not is_changing_scene: _play_next_in_queue()


func clear_cutscene_queue(): _cutscene_queue.clear(); print("SceneManager: Cutscene queue cleared.")

# --- Internal Playback Logic ---
# _validate_and_start_playback, _play_next_in_queue,
# _on_cutscene_playback_finished, _on_cutscene_playback_skipped,
# _handle_cutscene_completion
# (Implementations remain the same as provided)
func _validate_and_start_playback(cutscene_data: Dictionary) -> bool:
	if not video_player_scene: push_error("SceneManager: Cannot play cutscene, video_player_scene not set."); return false
	if not ResourceLoader.exists(cutscene_data.path): push_error("SceneManager: Video path not found: '%s'" % cutscene_data.path); return false
	is_playing_cutscene = true
	print("SceneManager: Starting cutscene: %s (Queued: %s)" % [cutscene_data.path, cutscene_data.is_queued])
	var video_stream = load(cutscene_data.path) as VideoStream
	if not video_stream: push_error("SceneManager: Failed to load video stream: %s" % cutscene_data.path); is_playing_cutscene = false; return false
	current_video_player_instance = video_player_scene.instantiate() as VideoPlayerLayer
	if not is_instance_valid(current_video_player_instance): push_error("SceneManager: Failed to instantiate video player scene."); video_stream = null; is_playing_cutscene = false; return false
	current_video_player_instance.set_meta("cutscene_data", cutscene_data)
	get_tree().root.add_child(current_video_player_instance)
	current_video_player_instance.playback_finished.connect(_on_cutscene_playback_finished.bind(cutscene_data), CONNECT_ONE_SHOT | CONNECT_REFERENCE_COUNTED)
	current_video_player_instance.playback_skipped.connect(_on_cutscene_playback_skipped.bind(cutscene_data), CONNECT_ONE_SHOT | CONNECT_REFERENCE_COUNTED)
	current_video_player_instance.play_sequence(video_stream, cutscene_data.pre_title, cutscene_data.post_title, cutscene_data.title_duration, cutscene_data.skip_action)
	return true

func _play_next_in_queue() -> void:
	if _cutscene_queue.is_empty(): print("SceneManager: Queue empty."); return
	if is_playing_cutscene or is_changing_scene: print("SceneManager: Busy, cannot play next in queue."); return
	var next_cutscene_data = _cutscene_queue.pop_front()
	if not _validate_and_start_playback(next_cutscene_data):
		push_warning("SceneManager: Failed to start queued item %s. Attempting next..." % next_cutscene_data.path)
		is_playing_cutscene = false
		call_deferred("_play_next_in_queue")

func _on_cutscene_playback_finished(finished_data: Dictionary) -> void: print("SceneManager: Cutscene finished: %s" % finished_data.path); _handle_cutscene_completion(false, finished_data)
func _on_cutscene_playback_skipped(skipped_data: Dictionary) -> void: print("SceneManager: Cutscene skipped: %s" % skipped_data.path); _handle_cutscene_completion(true, skipped_data)

func _handle_cutscene_completion(was_skipped: bool, completed_data: Dictionary) -> void:
	if is_instance_valid(current_video_player_instance): current_video_player_instance.queue_free(); current_video_player_instance = null
	else: push_warning("SceneManager: Video player instance invalid on completion.")
	is_playing_cutscene = false
	if completed_data.get("is_queued", false):
		if was_skipped: emit_signal("cutscene_queue_item_skipped", completed_data)
		else: emit_signal("cutscene_queue_item_finished", completed_data)
		if _cutscene_queue.is_empty(): print("SceneManager: Cutscene queue completed."); emit_signal("cutscene_queue_completed")
		else: print("SceneManager: Proceeding to next in queue."); call_deferred("_play_next_in_queue")
	else:
		if was_skipped: emit_signal("single_cutscene_skipped")
		else: emit_signal("single_cutscene_finished")
	print("SceneManager: Cutscene cleanup complete for: %s" % completed_data.get("path", "N/A"))


# --- Loading Screen Helpers ---
# _show_loading_screen, _hide_loading_screen
# (Implementations remain the same as provided)
func _show_loading_screen() -> void:
	if not is_instance_valid(current_loading_screen_instance):
		if not loading_screen_scene: push_error("SceneManager: Loading screen PackedScene is null."); return
		current_loading_screen_instance = loading_screen_scene.instantiate() as CanvasLayer
		if not current_loading_screen_instance: push_error("SceneManager: Failed to instantiate loading screen scene."); return
		get_tree().root.add_child(current_loading_screen_instance)
		print("SceneManager: Loading screen shown.")
	else: current_loading_screen_instance.show()

func _hide_loading_screen() -> void:
	if is_playing_cutscene: print("SceneManager: Not hiding loading screen, cutscene active."); return
	if is_instance_valid(current_loading_screen_instance):
		# Optional: Add fade out tween here
		current_loading_screen_instance.queue_free()
		current_loading_screen_instance = null
		print("SceneManager: Loading screen hidden.")
	else: current_loading_screen_instance = null

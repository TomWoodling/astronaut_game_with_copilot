# npc_controller.gd (Refactored for Godot 4.3, retaining original AnimStates)
extends CharacterBody3D
class_name NPController

# Signal emitted when the player attempts to interact with this NPC
# The listening system (e.g., InteractionManager, EncounterManager) will handle
# checking distance, encounters, and starting the actual dialog/encounter.
signal interaction_requested(npc: NPController)

# --- NPC Configuration ---
@export var npc_id: String = "generic_npc" # Unique identifier
@export var display_name: String = "Generic NPC" # Name shown to player (was npc_name)
@export_node_path("AnimationPlayer") var animation_player_path: NodePath
@export var interaction_distance: float = 2.0 # How close player needs to be (used by player's interaction system)
@export var npc_data: NPCInventoryData
# --- Data for Encounter/Dialog System ---
# These are now just data points for the system handling the interaction_requested signal
@export var available_encounters: Array[String] = []
@export var dialogue_id: String = "" # Default dialogue ID if no encounters are available/valid
@export var lookat_player: bool = false
# --- Node References ---
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path)
@onready var player = GameManager.player

# --- Animation States (Kept from original) ---
enum AnimState {
	IDLE,
	TALK1,
	TALK2,
	TALK3,
	MOOD1, # Often positive
	MOOD2, # Often negative
	DANCE  # Celebration
}
var current_anim_state: AnimState = AnimState.IDLE

# --- Animation Mappings (Kept from original) ---
const MOOD_ANIMATIONS = {
	"positive": AnimState.MOOD1,
	"negative": AnimState.MOOD2,
	# Using a random talk for neutral seems reasonable if TALK1 isn't specifically neutral
	#"neutral": AnimState.TALK1
}

const talk_anims = [AnimState.TALK1, AnimState.TALK2, AnimState.TALK3]

# --- NPC State ---
var is_currently_interacting: bool = false # Tracks if an interaction is *actively* happening

# --- Initialization ---

func _ready() -> void:
	if not animation_player:
		push_warning("NPCController [%s]: AnimationPlayer not found at path '%s'. Animations will not work." % [npc_id, animation_player_path])
	# Initialize idle animation using the internal method
	_set_animation_state(AnimState.IDLE)
	# Connect to player interaction signals

# --- Public Methods (Called externally) ---

# Called by the player's interaction system when interaction is triggered near this NPC
func request_interaction() -> void:
	# Only allow requesting interaction if not already interacting
	if not is_currently_interacting:
		emit_signal("interaction_requested", self)
		# Note: The actual distance check should happen in the player's interaction system
		# before calling this function.

# Called by EncounterManager/DialogManager to start the interaction visually
func start_interaction_state() -> void:
	if is_currently_interacting:
		return
	is_currently_interacting = true
	# Look towards player (implementation depends on your player tracking)
	# Example: look_at(player_position, Vector3.UP)
	_play_random_talk_animation(true) # Force play a talk animation

# Called by EncounterManager/DialogManager when the interaction flow ends
func end_interaction_state() -> void:
	if not is_currently_interacting:
		return
	is_currently_interacting = false
	_set_animation_state(AnimState.IDLE)

# Called by EncounterManager or Dialog system for greetings or acknowledgements
func play_greeting_animation() -> void:
	# Map "greeting" to one of the talk animations or keep idle?
	# Let's use TALK1 as a simple acknowledgement.
	_set_animation_state(AnimState.TALK1)

# Called by EncounterManager or Dialog system when NPC should appear to be talking
func play_talking_animation() -> void:
	# Use the random talk animation logic
	_play_random_talk_animation()

# Called by EncounterManager or Quest system upon success/celebration
func play_celebration_animation() -> void:
	_set_animation_state(AnimState.DANCE)

# Called by EncounterManager or Dialog system based on mood hints
func play_mood_animation(mood: String) -> void:
	var mood_lower = mood.to_lower()
	if mood_lower in MOOD_ANIMATIONS:
		_set_animation_state(MOOD_ANIMATIONS[mood_lower])
	else:
		# Fallback to a random talking animation if mood is unknown or neutral
		_play_random_talk_animation()

# Play specific animation by name (useful for animation_hint in dialog)
# Kept from original, slightly refined
func play_animation_by_name(anim_name: String) -> void:
	if not animation_player or anim_name.is_empty():
		return

	# Try to match with enum first (case-insensitive)
	for i in range(AnimState.values().size()):
		var enum_key = AnimState.keys()[i]
		if enum_key.to_upper() == anim_name.to_upper():
			# Found in enum, use the proper state setting method
			_set_animation_state(AnimState.values()[i])
			return

	# If not in enum, try direct animation name (PascalCase likely needed)
	var direct_anim_name = anim_name.to_pascal_case() # Assume PascalCase if not matching enum exactly
	if animation_player.has_animation(direct_anim_name):
		# Directly playing bypasses state tracking, might need adjustment
		# if complex state logic depends on current_anim_state
		animation_player.play(direct_anim_name)
		# Optionally reset tracked state or handle appropriately
		# current_anim_state = AnimState.IDLE # Or a custom state? Or leave it? Let's leave it for now.
		# print("NPCController [%s]: Playing animation directly: %s" % [npc_id, direct_anim_name])
	else:
		push_warning("NPCController [%s]: Animation '%s' (tried '%s') not found directly." % [npc_id, anim_name, direct_anim_name])


# --- Internal Animation Handling ---

# Renamed from play_animation, acts like set_animation_state from the new script
func _set_animation_state(new_state: AnimState, force_restart: bool = false) -> void:
	if not animation_player:
		return

	# Convert enum state to expected animation name (PascalCase)
	var anim_name = AnimState.keys()[new_state].to_pascal_case()

	if not animation_player.has_animation(anim_name):
		push_warning("NPCController [%s]: Animation '%s' (for state %s) not found." % [npc_id, anim_name, AnimState.keys()[new_state]])
		# Optionally fallback to Idle if the intended animation is missing
		if new_state != AnimState.IDLE and animation_player.has_animation("Idle"):
			animation_player.play("Idle")
			current_anim_state = AnimState.IDLE
		return

	# Play if the state is new, forced, or the current animation finished (looping handled by AnimationPlayer import settings)
	if new_state != current_anim_state or force_restart or not animation_player.is_playing():
		animation_player.play(anim_name)
		current_anim_state = new_state


# Renamed from get_random_talk_animation, plays a random talk animation
func _play_random_talk_animation(force_restart: bool = false) -> void:
	if talk_anims.is_empty():
		# Fallback if talk_anims is somehow empty - maybe play Idle or a default Talk?
		push_warning("NPCController [%s]: talk_anims array is empty!" % npc_id)
		_set_animation_state(AnimState.IDLE) # Or AnimState.TALK1 if it exists
		return

	var random_talk_state = talk_anims[randi() % talk_anims.size()]
	_set_animation_state(random_talk_state, force_restart)

# --- Removed Methods (Logic moved or replaced) ---
# - get_appropriate_encounter_id(): Logic now belongs in the system handling interaction_requested.
# - on_interaction_started(): Replaced by request_interaction() signal emission and start_interaction_state().
# - on_interaction_ended(): Replaced by end_interaction_state().
# - on_mood_change(): Replaced by play_mood_animation().
# - celebrate(): Renamed to play_celebration_animation().

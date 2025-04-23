# res://scripts/ui/scanner_display.gd
# Assumes this script is attached to the root Control node of ScannerDisplay.tscn
# which also has the HUDElement script attached or inherits from it.
class_name ScannerDisplay
extends HUDElement

@onready var progress_bar: ProgressBar = $VBoxContainer/ScanProgress
@onready var target_info: Label = $VBoxContainer/TargetInfo
@onready var range_indicator: TextureProgressBar = $VBoxContainer/RangeIndicator

var current_target = null # No ScannableObject class_name assumed

# HUDElement's _ready() handles initial hiding.
func _ready() -> void:
	# Connect to GameManager state changes if not done elsewhere
	if GameManager: # Check if GameManager exists before connecting
		GameManager.game_state_changed.connect(_on_game_state_changed)
	else:
		push_warning("ScannerDisplay: GameManager not found at _ready().")
	super._ready() # Call parent _ready (HUDElement's)


func _process(delta: float) -> void:
	# Only process if fully visible and tracking a target
	if not is_fully_visible() or not is_instance_valid(current_target):
		return

	# Check if ScannerManager exists and is scanning *this* target
	if ScannerManager and ScannerManager.is_scanning and ScannerManager.current_target == current_target:
		# Update Progress Bar smoothly
		progress_bar.value = lerp(progress_bar.value, ScannerManager.scan_progress * 100.0, delta * 10.0)

		# Update Range Indicator smoothly (ensure player exists)
		if is_instance_valid(GameManager.player):
			var distance = GameManager.player.global_position.distance_to(current_target.global_position)
			# Use safe division
			var scan_range = ScannerManager.SCAN_RANGE if ScannerManager and ScannerManager.SCAN_RANGE > 0 else 10.0 # Default fallback range
			var range_percent = clamp((1.0 - distance / scan_range) * 100.0, 0.0, 100.0)
			range_indicator.value = lerp(range_indicator.value, range_percent, delta * 10.0)
		else:
			range_indicator.value = 0 # Can't determine range
	elif ScannerManager and ScannerManager.current_target != current_target:
		# If ScannerManager stopped scanning *our* target without a signal HUDManager caught,
		# maybe hide? Better to rely on HUDManager reacting to scan_completed/failed signals.
		pass


## Sets up the display for a new scan target.
## Called by HUDManager *after* show_element().
func setup_display_for_scan(target) -> void: # Removed type hint
	# Basic check for target validity and data
	if not is_instance_valid(target) or not target.has_method("get_scan_data") or not target.collection_data:
		push_error("ScannerDisplay: Invalid target or missing required data/methods for setup.")
		current_target = null
		hide_element() # Hide if setup fails
		return

	current_target = target
	progress_bar.value = 0 # Reset progress visually
	range_indicator.value = 100 # Assume initially in range if scan started

	# Set Target Info Label
	target_info.text = target.collection_data.label if target.collection_data.label else "Unknown Object"

## Clears the display state. Called by HUDManager *before* hide_element().
func clear_display_state() -> void:
	current_target = null
	# Reset visual elements before fade-out begins
	target_info.text = ""
	progress_bar.value = 0
	range_indicator.value = 0

func _on_game_state_changed(_previous_state: GameManager.GameState, new_state: GameManager.GameState) -> void:
	# If the game is paused or stops playing, hide immediately (using HUDElement's method)
	if new_state != GameManager.GameState.PLAYING and visible:
		hide_element() # Let HUDElement handle the fade

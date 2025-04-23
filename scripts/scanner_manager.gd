# res://scripts/managers/scanner_manager.gd
# Autoload Singleton named 'ScannerManager'
# Manages the active scanning process, timing, state, and signals.
extends Node

# --- Signals ---
signal scan_started(target: Node) # Emitted when a scan begins successfully
signal scan_progress_updated(progress: float) # Emitted frequently during scan (0.0 to 1.0)
signal scan_completed(target: Node, scan_data: Dictionary) # Emitted on successful completion
signal scan_failed(target: Node, reason: String) # Emitted if scan fails mid-process (e.g., range)
signal scan_interrupted(reason: String) # Emitted if scan is cancelled externally (less likely now)

# --- Constants ---
const SCAN_RANGE: float = 6.0 # Maximum distance player can be from target DURING scan
const BASE_SCAN_TIME: float = 3.0 # Default time in seconds for a scan

# --- State Variables ---
var is_scanning: bool = false
var current_target = null # Will hold the ScannableObject being scanned
var scan_progress: float = 0.0 # Normalized progress (0.0 to 1.0)
var current_scan_timer: float = 0.0
var required_scan_time: float = BASE_SCAN_TIME

# --- Process ---
func _process(delta: float) -> void:
	# Only run the scan update logic if currently scanning
	if not is_scanning or not is_instance_valid(current_target):
		return

	# 1. Range Check (Mid-Scan)
	if not _is_target_in_range():
		_fail_scan("Target out of range")
		return

	# 2. Update Timer & Progress
	current_scan_timer += delta
	scan_progress = clamp(current_scan_timer / required_scan_time, 0.0, 1.0)
	scan_progress_updated.emit(scan_progress) # Notify HUD etc.

	# 3. Check for Completion
	if scan_progress >= 1.0:
		_complete_scan()


# --- Public Methods ---

## Called by PlayerInteraction to initiate a scan on a validated target.
func start_scan(target) -> void: # Removed type hint for flexibility
	if is_scanning:
		push_warning("ScannerManager: Already scanning, cannot start new scan.")
		return
	if not is_instance_valid(target) or not target.has_method("get_scan_data"):
		push_error("ScannerManager: Invalid target provided for scanning.")
		return
	# Double check range on initiation, though PlayerInteraction likely did
	if not _is_target_in_range(target):
		push_warning("ScannerManager: Target out of range at scan initiation.")
		# Optionally provide feedback via HUDManager.show_message
		return

	print("ScannerManager: Starting scan on ", target.name)
	is_scanning = true
	current_target = target
	scan_progress = 0.0
	current_scan_timer = 0.0

	# Calculate actual scan time based on base time and target difficulty
	var difficulty = 0.0
	if target.has_method("get_scan_difficulty"):
		difficulty = clamp(target.get_scan_difficulty(), 0.0, 0.9) # Clamp difficulty to avoid zero/negative time
	required_scan_time = BASE_SCAN_TIME / (1.0 - difficulty) # Higher difficulty = longer scan
	
	current_target.start_scan_effect()
	# Update Gameplay State
	GameManager.set_gameplay_state(GameManager.GameplayState.SCANNING)

	# Emit Signal
	scan_started.emit(current_target)

## Can be called externally if needed, though less common now.
## Primarily used internally for failures.
func interrupt_scan(reason: String) -> void:
	if not is_scanning:
		return

	print("ScannerManager: Scan interrupted. Reason: ", reason)
	var target_ref = current_target # Keep ref for signal
	_reset_scan_state()

	# Ensure player state is reset
	if GameManager.get_current_gameplay_state() == GameManager.GameplayState.SCANNING:
		GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)

	scan_interrupted.emit(reason)
	# Also tell the target to stop its effect (might be redundant if it listens to interrupted signal)
	if is_instance_valid(target_ref) and target_ref.has_method("stop_scan_effect"):
		target_ref.stop_scan_effect()


# --- Internal Helper Methods ---

## Checks if the current target is within the allowed scanning range.
func _is_target_in_range(target_override = null) -> bool:
	var target_to_check = target_override if target_override else current_target
	if not is_instance_valid(target_to_check) or not is_instance_valid(GameManager.player):
		return false # Cannot check range if target or player is invalid

	var distance = GameManager.player.global_position.distance_to(target_to_check.global_position)
	return distance <= SCAN_RANGE

## Handles the logic for completing a scan successfully.
func _complete_scan() -> void:
	print("ScannerManager: Scan completed for ", current_target.name)
	var target_ref = current_target # Keep ref for signal/data retrieval
	var scan_data = {}

	# Get data and mark object as scanned
	scan_data = target_ref.get_scan_data() # This also sets target.has_been_scanned = true

	_reset_scan_state()

	# Emit completion signal AFTER resetting state but before changing gameplay state
	scan_completed.emit(target_ref, scan_data)

	# Reset Gameplay State (allow other systems to react to completion first)
	# Check if we are still in scanning state before resetting (e.g. maybe game paused)
	if GameManager.get_current_gameplay_state() == GameManager.GameplayState.SCANNING:
		GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)


## Handles the logic for failing a scan mid-process.
func _fail_scan(reason: String) -> void:
	if not is_scanning: return # Should not happen, but safety check

	print("ScannerManager: Scan failed for ", current_target.name, ". Reason: ", reason)
	var target_ref = current_target # Keep ref for signal
	_reset_scan_state()

	# Ensure player state is reset
	if GameManager.get_current_gameplay_state() == GameManager.GameplayState.SCANNING:
		GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)

	scan_failed.emit(target_ref, reason)
	# Tell the target to stop its effect
	if is_instance_valid(target_ref) and target_ref.has_method("stop_scan_effect"):
		target_ref.stop_scan_effect()


## Resets internal scanning state variables.
func _reset_scan_state() -> void:
	is_scanning = false
	current_target = null
	scan_progress = 0.0
	current_scan_timer = 0.0
	required_scan_time = BASE_SCAN_TIME

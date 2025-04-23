# res://scripts/player/player_animation.gd (Corrected PascalCase & Getters)
extends AnimationTree

@onready var parent_char_body: CharacterBody3D = get_parent().get_parent() as CharacterBody3D
@onready var animation_state_machine: AnimationNodeStateMachinePlayback = get("parameters/playback")
@onready var fall_detector: FallDetector = parent_char_body.get_node_or_null("FallDetector")
@onready var back_bone: Node3D = %Backpack
@onready var right_hand: Node3D = %RightHand
@onready var left_hand: Node3D = %LeftHand # Scanner hand
var _animation_player: AnimationPlayer = null # Cache AnimationPlayer reference

# Animation Exports (Keep as is)
@export_group("Animation Thresholds")
@export var splat_anim_duration: float = 1.6
@export var stand_anim_duration: float = 2.2667

# Enum for internal tracking - names match PascalCase states
enum AnimState { Idle, Walk, Run, Jump, Falling, Splat, Stand, Success, EquipScan, Scan, Talk, Dance }

# State tracking
var current_anim_enum_state: AnimState = AnimState.Idle
var previous_gameplay_state_enum: GameManager.GameplayState
var animation_locked: bool = false
var cutscene_anim: AnimState = AnimState.Idle
var cutscene_state: bool = true

func _ready() -> void:
	# --- Validation ---
	if not parent_char_body is CharacterBody3D: push_error("PlayerAnimation: Parent not CharacterBody3D!"); set_process(false); return
	if not fall_detector: fall_detector = parent_char_body.get_node_or_null("FallDetector")
	if not fall_detector: push_error("PlayerAnimation: FallDetector not found!"); set_process(false); return
	if not animation_state_machine: push_error("PlayerAnimation: StateMachinePlayback not found!"); set_process(false); return
	_animation_player = parent_char_body.get_node_or_null("meshy_snaut/AnimationPlayer")
	if not _animation_player: push_error("PlayerAnimation: AnimationPlayer not found!"); set_process(false); return
	# --- End Validation ---

	# Connect AnimationPlayer signal
	_animation_player.animation_finished.connect(_on_animation_finished)

	# Set initial state (Use PascalCase name)
	animation_state_machine.travel("Idle")
	current_anim_enum_state = AnimState.Idle # Sync enum tracker

	_connect_external_signals()

	if GameManager: previous_gameplay_state_enum = GameManager.get_current_gameplay_state()
	else: push_warning("PlayerAnimation: GameManager not found."); previous_gameplay_state_enum = GameManager.GameplayState.NORMAL

	# Initial equipment visibility (Keep as is)
	if left_hand: left_hand.visible = false
	if right_hand: right_hand.visible = false
	if back_bone: back_bone.visible = true


func _connect_external_signals() -> void:
	# Connections (Keep As Is)
	if ScannerManager:
		ScannerManager.scan_completed.connect(_on_scan_completed)
		ScannerManager.scan_started.connect(_on_scan_started)
		ScannerManager.scan_failed.connect(_on_scan_ended_abruptly)
		ScannerManager.scan_interrupted.connect(_on_scan_ended_abruptly)
	if fall_detector:
		fall_detector.falling_state_changed.connect(_on_falling_state_changed)
		fall_detector.player_landed.connect(_on_player_landed)
	if MissionManager:
		MissionManager.request_cutscene_animation.connect(_handle_cutscene_request)

func _physics_process(delta: float) -> void:
	if not GameManager: return
	if animation_locked: return

	var current_gameplay_state = GameManager.get_current_gameplay_state()

	# Handle STUNNED state
	if current_gameplay_state == GameManager.GameplayState.STUNNED:
		if current_anim_enum_state != AnimState.Splat and current_anim_enum_state != AnimState.Stand:
			_apply_animation_state(AnimState.Splat) # Use Enum
		return

	# Handle non-controllable states
	if not GameManager.is_player_controllable():
		if current_gameplay_state == GameManager.GameplayState.DIALOGUE:
			if current_anim_enum_state != AnimState.Talk: _apply_animation_state(AnimState.Talk) # Use Enum
		elif current_gameplay_state == GameManager.GameplayState.SCANNING:
			if current_anim_enum_state != AnimState.EquipScan and current_anim_enum_state != AnimState.Scan:
				_apply_animation_state(AnimState.EquipScan) # Use Enum
		elif current_gameplay_state == GameManager.GameplayState.CUTSCENE:
			_apply_animation_state(cutscene_anim)
		elif current_anim_enum_state != AnimState.Idle:
			_apply_animation_state(AnimState.Idle) # Use Enum

		previous_gameplay_state_enum = current_gameplay_state
		return

	# --- Regular Movement Animation Logic ---
	if current_gameplay_state != previous_gameplay_state_enum:
		previous_gameplay_state_enum = current_gameplay_state

	if current_anim_enum_state == AnimState.Falling: return # Handled by signals

	# --- Use Corrected Getters ---
	var on_floor: bool = parent_char_body.is_on_floor()
	var is_running: bool = parent_char_body.is_player_running()
	var is_walking: bool = parent_char_body.is_player_walking() # NEW Getter
	var is_jumping: bool = parent_char_body.get_is_jumping()
	var is_moving: bool = is_running or is_walking # Helper to check if any ground movement input is active
	# --- End Getters ---

	var target_state_enum: AnimState

	if is_jumping:
		target_state_enum = AnimState.Jump # Use Enum
	elif on_floor:
		if is_running: # Check running first (default)
			target_state_enum = AnimState.Run # Use Enum
		elif is_walking: # Check walking next
			target_state_enum = AnimState.Walk # Use Enum
		else: # Not moving
			target_state_enum = AnimState.Idle # Use Enum
	else: # In air, not jumping
		if current_anim_enum_state != AnimState.Falling:
			target_state_enum = AnimState.Jump # Use Enum (for small falls/apex)
		else:
			target_state_enum = AnimState.Falling # Remain falling

	# Apply the animation if different
	if target_state_enum != current_anim_enum_state:
		_apply_animation_state(target_state_enum) # Use Enum


# --- Signal Handlers (Use Enums for state checks/setting) ---

func _on_falling_state_changed(is_falling: bool) -> void:
	if animation_locked or GameManager.get_current_gameplay_state() == GameManager.GameplayState.STUNNED: return

	if is_falling:
		_apply_animation_state(AnimState.Falling) # Use Enum
	elif current_anim_enum_state == AnimState.Falling:
		var on_floor = parent_char_body.is_on_floor()
		var is_jumping = parent_char_body.get_is_jumping()
		var new_state_enum: AnimState = AnimState.Jump # Default if still airborne
		if on_floor: new_state_enum = AnimState.Idle # Landed
		_apply_animation_state(new_state_enum) # Use Enum

func _on_player_landed() -> void:
	if current_anim_enum_state == AnimState.Falling:
		_apply_animation_state(AnimState.Splat) # Use Enum

# --- Scan Signal Handlers (Use Enums) ---
func _on_scan_started(_target) -> void:
	if current_anim_enum_state == AnimState.Splat or current_anim_enum_state == AnimState.Stand: return
	_apply_animation_state(AnimState.EquipScan) # Use Enum
	if left_hand: left_hand.visible = true

func _on_scan_completed(_target, _scan_data) -> void:
	if left_hand: left_hand.visible = false
	_play_success_animation() # Success uses Enum internally

func _on_scan_ended_abruptly(_arg1 = null, _arg2 = null) -> void:
	if current_anim_enum_state == AnimState.Scan or current_anim_enum_state == AnimState.EquipScan:
		if left_hand: left_hand.visible = false
		animation_locked = false
		# Re-evaluate movement state using parent getters
		var on_floor = parent_char_body.is_on_floor()
		var is_running = parent_char_body.is_player_running()
		var is_walking = parent_char_body.is_player_walking()
		var is_jumping = parent_char_body.get_is_jumping()
		var new_state_enum: AnimState = AnimState.Idle
		if is_jumping: new_state_enum = AnimState.Jump
		elif on_floor: new_state_enum = AnimState.Run if is_running else (AnimState.Walk if is_walking else AnimState.Idle)
		else: new_state_enum = AnimState.Jump
		_apply_animation_state(new_state_enum) # Use Enum


# --- Success Animation (Use Enum) ---
func _play_success_animation() -> void:
	if current_anim_enum_state != AnimState.Splat and \
	   current_anim_enum_state != AnimState.Stand and \
	   current_anim_enum_state != AnimState.Success and \
	   current_anim_enum_state != AnimState.Falling:
		_apply_animation_state(AnimState.Success) # Use Enum
		animation_locked = true
		if _animation_player:
			await _animation_player.animation_finished
			if current_anim_enum_state == AnimState.Success and animation_locked:
				_on_success_anim_finished() # Call handler


# --- Animation State Application (Use PascalCase state names) ---
func _apply_animation_state(new_state_enum: AnimState) -> void:
	if new_state_enum == current_anim_enum_state or not animation_state_machine: return

	# Convert Enum to PascalCase String for travel()
	var state_name_string: String = AnimState.keys()[new_state_enum]

	# print("Player Animation State Enum: ", state_name_string) # Debugging
	animation_state_machine.travel(state_name_string) # Use the string name
	current_anim_enum_state = new_state_enum # Update enum tracker

	# Handle logic specific to entering states (using Enum for match)
	match current_anim_enum_state:
		AnimState.Splat: GameManager.set_gameplay_state(GameManager.GameplayState.STUNNED)
		AnimState.Stand: animation_locked = true
		AnimState.EquipScan: animation_locked = true
		_: pass


# --- Animation Finished Handler (Use PascalCase names for matching) ---
func _on_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		&"Splat": # PascalCase
			if GameManager.get_current_gameplay_state() == GameManager.GameplayState.STUNNED:
				_apply_animation_state(AnimState.Stand) # Use Enum
			elif GameManager.get_current_gameplay_state() == GameManager.GameplayState.CUTSCENE:
				_apply_animation_state(AnimState.Stand) # Use Enum
		&"Stand": # PascalCase
			animation_locked = false
			if GameManager.get_current_gameplay_state() == GameManager.GameplayState.STUNNED:
				GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
				_apply_animation_state(AnimState.Idle) # Use Enum
			elif GameManager.get_current_gameplay_state() == GameManager.GameplayState.CUTSCENE:
				GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
				_apply_animation_state(AnimState.Idle) # Use Enum
		&"EquipScan": # PascalCase
			if GameManager.get_current_gameplay_state() == GameManager.GameplayState.SCANNING:
				_apply_animation_state(AnimState.Scan) # Use Enum
			animation_locked = false
		&"Success": # PascalCase
			_on_success_anim_finished() # Call handler


# --- Success Animation Finished Handler (Use Enums) ---
func _on_success_anim_finished() -> void: # No longer needs anim_name arg
	if animation_locked and current_anim_enum_state == AnimState.Success:
		animation_locked = false
		# Re-evaluate movement state using parent getters
		var on_floor = parent_char_body.is_on_floor()
		var is_running = parent_char_body.is_player_running()
		var is_walking = parent_char_body.is_player_walking()
		var target_state_enum: AnimState = AnimState.Idle
		if not on_floor: target_state_enum = AnimState.Jump
		elif is_running: target_state_enum = AnimState.Run
		elif is_walking: target_state_enum = AnimState.Walk

		_apply_animation_state(target_state_enum) # Use Enum

func _handle_cutscene_request(anim,state:bool):
	print(anim)
	match anim:
		"Walk":
			if state:
				cutscene_anim = AnimState.Walk
			else:
				cutscene_anim = AnimState.Idle

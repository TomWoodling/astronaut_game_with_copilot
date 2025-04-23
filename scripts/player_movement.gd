# res://scripts/player/player_movement.gd
# CORRECTED Run/Walk Logic
extends CharacterBody3D

# --- Movement Exports (Interpret `walk_speed` as base, add `walk_multiplier`) ---
@export_group("Astronaut Movement")
# RENAME walk_speed to base_speed or move_speed for clarity? Let's keep walk_speed for now but treat it as base.
@export var walk_speed: float = 4.0 # This is the BASE speed (running)
# RENAME run_multiplier to walk_multiplier? Let's use walk_multiplier.
@export var walk_multiplier: float = 0.5 # Multiplier when holding "walk" action (e.g., 0.5 for half speed)
@export var acceleration: float = 5.0
@export var friction: float = 2.0 # Still not directly used, acceleration handles stopping
@export var rotation_speed: float = 4.0
@export var rotation_acceleration: float = 8.0
@export var rotation_deceleration: float = 4.0

# --- Lunar Jump Parameters (Keep As Is) ---
@export_group("Lunar Jump Parameters")
@export var jump_strength: float = 12.0
@export var jump_horizontal_force: float = 4.0
@export var air_damping: float = 0.25
@export var gravity: float = 5.0
@export var max_fall_speed: float = 15.0
@export var air_control: float = 0.6
@export var air_brake: float = 0.15
@export var landing_cushion: float = 2.0

# --- State Modifiers (Keep As Is, applied to BASE speed) ---
@export_group("State Modifiers")
@export var scanning_speed_mult: float = 0.5
@export var scanning_rotation_mult: float = 0.5
@export var stunned_speed_mult: float = 0.0
@export var stunned_rotation_mult: float = 0.0
@export var stunned_recovery_speed_mult: float = 0.3

# --- Constants ---
const JUMP_DURATION: float = 0.6

# --- Node References (Keep As Is) ---
@export var camera_rig: Node3D
@export var mesh: Node3D
@export var fall_detector: FallDetector

# --- Movement State (Keep As Is) ---
var move_direction: Vector3 = Vector3.ZERO
var camera_basis: Basis = Basis.IDENTITY
var target_basis: Basis = Basis.IDENTITY
var current_rotation_speed: float = 0.0
var was_in_air: bool = false
var current_speed: float = 0.0

# --- Jump State (Keep As Is) ---
var jump_time: float = 0.0
var is_jumping: bool = false
var can_jump: bool = true
var _is_falling: bool = false

# --- Internal ---
var _original_air_control: float = 1.0

func _ready() -> void:
	# Validation (Keep As Is)
	if not camera_rig: push_error("PlayerMovement: CameraRig node not assigned!")
	if not mesh: push_error("PlayerMovement: Mesh node not assigned!")
	if not fall_detector or not fall_detector is FallDetector:
		push_error("PlayerMovement: FallDetector node not assigned or not correct type!")
	if not GameManager:
		push_error("PlayerMovement: GameManager Autoload not found!")
		set_physics_process(false)
		return

	_original_air_control = air_control
	GameManager.player = self
	print("player_movement: Player reference set in GameManager.")
	# Connect signals (Keep As Is)
	if camera_rig.has_signal("camera_rotated"):
		camera_rig.connect("camera_rotated", _on_camera_rotated)
	else:
		push_warning("PlayerMovement: CameraRig does not have 'camera_rotated' signal.")
	if fall_detector: # Check if fall_detector is valid before connecting
		fall_detector.falling_state_changed.connect(_on_falling_state_changed)
		fall_detector.player_landed.connect(_on_player_landed)

	target_basis = mesh.global_basis


func _physics_process(delta: float) -> void:
	if not GameManager.is_player_controllable():
		# Handle non-controllable state (Keep As Is)
		if not is_on_floor():
			velocity.y = move_toward(velocity.y, -max_fall_speed, gravity * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		move_and_slide()
		return

	var on_floor = is_on_floor()

	if was_in_air and on_floor:
		_handle_landing()
		can_jump = true
		is_jumping = false
		jump_time = 0.0
	was_in_air = not on_floor

	var speed_modifier = _get_speed_modifier()
	var rotation_modifier = _get_rotation_modifier()

	if Input.is_action_just_pressed("jump") and can_jump and on_floor:
		_initiate_jump()

	_update_jump_state(delta, on_floor)
	_handle_movement_input(delta, on_floor, speed_modifier, rotation_modifier)
	move_and_slide()


# --- Input & Movement (CORRECTED Run/Walk Logic) ---

func _handle_movement_input(delta: float, on_floor: bool, speed_mod: float, rot_mod: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# --- CORRECTED: Check for "walk" input ---
	var walk_input_pressed = Input.is_action_pressed("walk") # Assume "walk" is your precision movement action

	move_direction = Vector3.ZERO
	if input_dir != Vector2.ZERO:
		# Direction calculation (Keep As Is)
		var forward = -camera_basis.z
		forward.y = 0; forward = forward.normalized()
		var right = camera_basis.x
		right.y = 0; right = right.normalized()
		move_direction = (forward * -input_dir.y + right * input_dir.x).normalized()

	# Rotation (Keep As Is)
	if move_direction != Vector3.ZERO:
		target_basis = Basis.looking_at(move_direction, Vector3.UP)
		var current_rotation_acceleration = rotation_acceleration * rot_mod
		if not on_floor: current_rotation_acceleration *= air_control
		current_rotation_speed = move_toward(current_rotation_speed, rotation_speed * rot_mod, current_rotation_acceleration * delta)
		mesh.global_basis = mesh.global_basis.slerp(target_basis, current_rotation_speed * delta).orthonormalized()
	else:
		current_rotation_speed = move_toward(current_rotation_speed, 0.0, rotation_deceleration * delta)

	# --- Velocity (CORRECTED Speed Calculation) ---
	# Determine target speed: Start with base speed (walk_speed), then apply walk modifier if pressed.
	var target_base_speed = walk_speed # Base speed is the 'running' speed
	if walk_input_pressed:
		target_base_speed *= walk_multiplier # Apply modifier for precision walking

	# Apply overall state modifiers (scanning, stunned) AFTER walk/run logic
	var effective_target_speed = target_base_speed * speed_mod

	var target_h_velocity: Vector3

	if move_direction != Vector3.ZERO:
		# Smoothly approach the effective target speed
		current_speed = move_toward(current_speed, effective_target_speed, acceleration * delta)
		target_h_velocity = move_direction * current_speed
	else:
		# Decelerate horizontal speed (friction)
		current_speed = move_toward(current_speed, 0.0, acceleration * delta)
		target_h_velocity = Vector3(
			move_toward(velocity.x, 0.0, acceleration * delta),
			0,
			move_toward(velocity.z, 0.0, acceleration * delta)
		)

	# Apply horizontal velocity (Keep As Is - handles on_floor/air_control)
	if on_floor:
		velocity.x = target_h_velocity.x
		velocity.z = target_h_velocity.z
	else: # In air
		var effective_air_control = air_control
		var air_target_h_velocity = target_h_velocity * effective_air_control
		velocity.x = move_toward(velocity.x, air_target_h_velocity.x, acceleration * effective_air_control * delta)
		velocity.z = move_toward(velocity.z, air_target_h_velocity.z, acceleration * effective_air_control * delta)
		if move_direction == Vector3.ZERO:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * air_brake * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * air_brake * delta)


# --- Jump & Landing (CORRECTED Jump Momentum) ---

func _initiate_jump() -> void:
	is_jumping = true
	can_jump = false
	jump_time = 0.0
	velocity.y = jump_strength
	_apply_jump_horizontal_momentum()

func _update_jump_state(delta: float, on_floor: bool) -> void:
	# Keep jump update logic As Is
	if is_jumping:
		jump_time += delta
		if jump_time >= JUMP_DURATION:
			is_jumping = false
	if not on_floor:
		velocity.y = move_toward(velocity.y, -max_fall_speed, gravity * delta)
	elif velocity.y < 0:
		velocity.y = 0

func _apply_jump_horizontal_momentum() -> void:
	if move_direction != Vector3.ZERO:
		# --- CORRECTED: Check "walk" input for jump momentum ---
		var walk_input_pressed = Input.is_action_pressed("walk")
		var h_force = jump_horizontal_force
		# If walking, reduce jump momentum slightly? (Optional refinement)
		# if walk_input_pressed:
		#     h_force *= walk_multiplier # Apply walk multiplier to horizontal jump force too?

		var jump_h_velocity = move_direction * h_force
		velocity.x += jump_h_velocity.x
		velocity.z += jump_h_velocity.z

func _handle_landing() -> void:
	# Keep landing cushion logic As Is
	if velocity.y < 0:
		velocity.y = velocity.y / landing_cushion


# --- State Modifiers (Keep As Is - logic relies on GameManager state) ---

func _get_speed_modifier() -> float:
	match GameManager.get_current_gameplay_state():
		GameManager.GameplayState.SCANNING:
			return scanning_speed_mult
		GameManager.GameplayState.STUNNED:
			return stunned_speed_mult
		_:
			return 1.0

func _get_rotation_modifier() -> float:
	match GameManager.get_current_gameplay_state():
		GameManager.GameplayState.SCANNING:
			return scanning_rotation_mult
		GameManager.GameplayState.STUNNED:
			return stunned_rotation_mult
		_:
			return 1.0


# --- Signal Handlers (Keep As Is) ---

func _on_camera_rotated(new_basis: Basis) -> void:
	camera_basis = new_basis

func _on_falling_state_changed(falling: bool) -> void:
	_is_falling = falling
	if falling: air_control = _original_air_control * 0.7
	else: air_control = _original_air_control

func _on_player_landed() -> void:
	pass


# --- Public Getters for Animation (CORRECTED) ---
func is_player_running() -> bool:
	# Running is the default when moving and NOT pressing walk
	var walk_input_pressed = Input.is_action_pressed("walk")
	# Need current horizontal speed to determine if actually moving
	var h_speed = Vector2(velocity.x, velocity.z).length()
	return not walk_input_pressed and h_speed > 0.1 and GameManager.is_player_controllable() and is_on_floor()

# --- NEW Getter for Walking State ---
func is_player_walking() -> bool:
	# Walking is when pressing walk AND moving
	var walk_input_pressed = Input.is_action_pressed("walk")
	var h_speed = Vector2(velocity.x, velocity.z).length()
	return walk_input_pressed and h_speed > 0.1 and GameManager.is_player_controllable() and is_on_floor()

func get_is_jumping() -> bool:
	return is_jumping

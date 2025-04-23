# Modified fall_detector.gd to remove "hard landing" complexity
extends RayCast3D

class_name FallDetector

# Signal to notify other systems of falling state changes
signal falling_state_changed(is_falling: bool)
signal player_landed()  # Simplified signal - replaces hard_landing_detected

# Reference to the player character
@onready var parent: CharacterBody3D = get_parent()
@onready var shadow_plane: MeshInstance3D = $"../ShadowPlane"

# Configuration
@export var fall_detection_distance: float = 12.0  # Distance to check for ground
@export var fall_detection_delay: float = 0.3      # Time to wait after apex before triggering falling

# State tracking
var is_falling: bool = false
var was_ascending: bool = false
var fall_apex_reached: bool = false
var apex_timer: float = 0.0
var was_on_floor: bool = true
var cutscene_fall: bool = false

func _ready() -> void:
	# Set target distance
	target_position = Vector3(0, -fall_detection_distance, 0)
	
	# Set debug visualization
	debug_shape_thickness = 2.0
	debug_shape_custom_color = Color(1, 0.5, 0, 0.5)  # Orange for fall detector

	# Set initial shadow visibility to false
	shadow_plane.visible = false

func _physics_process(delta: float) -> void:
	# Skip processing if player is stunned
	if GameManager and GameManager.get_current_gameplay_state() == GameManager.GameplayState.STUNNED:
		return
	elif GameManager and GameManager.get_current_gameplay_state() == GameManager.GameplayState.CUTSCENE:
		if MissionManager.cutscene_fall == true:
			cutscene_fall_handling()
		
	var current_y_velocity = parent.velocity.y
	var on_floor = parent.is_on_floor()
	
	# Check for landing after falling
	if is_falling and !was_on_floor and on_floor:
		_handle_landing()
	
	# Only check for falling state if player is not on floor
	if !on_floor:
		# Check if player has reached apex of jump (was going up, now going down)
		if was_ascending and current_y_velocity < 0:
			fall_apex_reached = true
			apex_timer = 0.0
		
		# If apex reached, start timer
		if fall_apex_reached:
			apex_timer += delta
			
			# If timer exceeds delay and no ground detected below, trigger falling state
			if apex_timer > fall_detection_delay and !is_colliding():
				if !is_falling:
					is_falling = true
					falling_state_changed.emit(true)
					# Debug visualization
					debug_shape_custom_color = Color(1, 0, 0, 0.5)  # Red when falling detected
		
		# Update tracking state
		was_ascending = current_y_velocity > 0
		
		# Update the shadow position
		update_shadow_position()
	else:
		# If we were falling and now we're not, emit signal
		if is_falling:
			is_falling = false
			falling_state_changed.emit(false)
			# Debug visualization
			debug_shape_custom_color = Color(1, 0.5, 0, 0.5)  # Back to orange
		
		# Reset falling state tracking
		fall_apex_reached = false
		apex_timer = 0.0
		shadow_plane.visible = false
	
	# Update floor state tracking
	was_on_floor = on_floor

func _handle_landing() -> void:
	# Simplified landing detection - if we were falling and now landed, always notify
	player_landed.emit()
	if MissionManager.cutscene_fall == true:
		MissionManager.cutscene_fall = false

func update_shadow_position() -> void:
	# Update the raycast to check for collisions
	force_raycast_update()
	
	if is_colliding():
		# If there is a collision, get the collision point and move the shadow plane there
		var collision_point = get_collision_point()
		shadow_plane.global_transform.origin = collision_point
		
		# Make the shadow visible when the raycast collides
		shadow_plane.visible = true
	else:
		# Hide the shadow if no collision is detected
		shadow_plane.visible = false

func cutscene_fall_handling():
	var current_y_velocity = parent.velocity.y
	var on_floor = parent.is_on_floor()
	if is_falling and on_floor:
		print("whatever fall floor")
		_handle_landing()
	if MissionManager.cutscene_fall:
		is_falling = true
		falling_state_changed.emit(true)
	else:
		is_falling = false
		falling_state_changed.emit(false)
	# Update floor state tracking
	was_on_floor = on_floor

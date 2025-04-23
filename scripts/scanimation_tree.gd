extends AnimationTree
class_name ScanimationTree

@onready var animation_state_machine: AnimationNodeStateMachinePlayback = get("parameters/playback")
@onready var player_detect_zone = $PlayerDetect
@onready var in_action: bool = false
@onready var collision_shape : CollisionShape3D = $PlayerDetect/CollisionShape3D

# Timers for controlling state transitions
var move_to_action_timer: float = 0.0
var move_to_action_wait_time: float = 0.0
var action_cooldown_timer: float = 0.0
var action_cooldown_wait_time: float = 0.0

# Player detection state
var player_near: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var new_shape : BoxShape3D = BoxShape3D.new()
	collision_shape.shape = new_shape
	var shape := collision_shape.shape
	if shape is BoxShape3D:
		var unique_shape := shape.duplicate() as BoxShape3D
		collision_shape.shape = unique_shape  # Assign the unique copy back
		unique_shape.size = Vector3(8,8,8)
		collision_shape.global_transform.origin = get_parent().global_transform.origin
	else:
		push_warning("Collision shape is not a BoxShape3D")
		return false
	# Set initial state to Idle
	animation_state_machine.travel("Idle")
	
	# Initialize random wait times
	_reset_move_to_action_timer()
	_reset_action_cooldown_timer()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if player_near:
		if animation_state_machine.get_current_node() == "Move":
			# Count down timer for Move to Action transition
			if move_to_action_timer > 0:
				move_to_action_timer -= delta
				if move_to_action_timer <= 0:
					_do_action()
			
			# Count down cooldown timer after Action completed
			if action_cooldown_timer > 0:
				action_cooldown_timer -= delta
				if action_cooldown_timer <= 0:
					_do_action()

# Reset the Move to Action timer with a random duration between 3-5 seconds
func _reset_move_to_action_timer():
	move_to_action_wait_time = randf_range(3.0, 5.0)
	move_to_action_timer = move_to_action_wait_time

# Reset the Action cooldown timer with a random duration between 5-10 seconds
func _reset_action_cooldown_timer():
	action_cooldown_wait_time = randf_range(5.0, 10.0)
	action_cooldown_timer = action_cooldown_wait_time

# Player enters detection zone
func _on_player_detect_body_entered(body):
	if body.is_in_group("player"):
		player_near = true
		#print("nearby")
		
		# Start Move animation if not already in Action
		if !in_action:
			#print("goto Move")
			animation_state_machine.travel("Move")
			_reset_move_to_action_timer()

# Trigger the Action animation
func _do_action():
	#print("doing Action")
	animation_state_machine.travel("Action")
	in_action = true
	# Reset timers - they'll be used after Action completes
	action_cooldown_timer = 0.0
	move_to_action_timer = 0.0

# Handle animation finished signal
func _on_animation_finished(anim_name):
	match anim_name:
		"Action":
			in_action = false
			
			# After Action finishes, go to Move and start cooldown timer
			if player_near:
				animation_state_machine.travel("Move")
				_reset_action_cooldown_timer()
			else:
				# If player left during action, go back to Idle
				animation_state_machine.travel("Idle")

# Player exits detection zone
func _on_player_detect_body_exited(body):
	if body.is_in_group("player"):
		player_near = false
		#print("exit zone")
		# If not in Action, return to Idle immediately
		if !in_action:
			animation_state_machine.travel("Idle")
		# Otherwise, let the action finish
		# The _on_animation_finished handler will send it back to Idle

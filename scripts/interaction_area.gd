# res://scripts/player/player_interaction.gd
# Attach this script TO THE 'InteractionArea' (Area3D) node within player.tscn.
# Ensure InteractionArea is on Layer 2, Mask 8.
extends Area3D

# Stores valid ScannableObject nodes currently being overlapped
var overlapping_scannables: Array[Node] = []
# Tracks the single closest target that should be highlighted
var closest_highlighted_target: Node = null
var override_target: Node = null

func _ready() -> void:
	# Connect signals FROM this Area3D TO methods in this script
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Optional: Programmatically set mask just in case
	# Mask bit 7 corresponds to Layer 8 (0-indexed bits)
	collision_mask = collision_mask | (1 << 7)


func _input(event: InputEvent) -> void:
	# Check if player control is allowed by GameManager
	if not GameManager.is_player_controllable():
		return
	
	if not GameManager.is_player_controllable(): return

	if event.is_action_pressed("interact"):
		override_target = MissionManager.mission_interactable
		if is_instance_valid(closest_highlighted_target):
			# --- REVISED ---
			# The 'closest_highlighted_target' IS the interactable thing (NPC body, Item body)
			# Check if IT has an interact method (provided by a script like NPCInteractionLogic or ItemInteractionLogic)
			if closest_highlighted_target.has_method("interact"):
				print("call interact")
				# Call interact() on the target itself. That target's script
				# will then call get_parent().report_trigger_met() if it's part of an objective.
				closest_highlighted_target.interact()
				get_viewport().set_input_as_handled()
				return
		elif is_instance_valid(override_target):
			if override_target.has_method("interact"):
				print("call interact")
				override_target.interact()
				get_viewport().set_input_as_handled()
				MissionManager.mission_interactable = null
				return
			
	# Check for the "scan" action
	if event.is_action_pressed("scan"):
		# Try to scan the currently highlighted target (determined by _physics_process)
		if is_instance_valid(closest_highlighted_target):
			# Double-check distance from the player's body (parent of this Area3D)
			var player_body = get_parent() as Node3D # Assumes parent is CharacterBody3D
			if not player_body: return # Safety check

			var dist = player_body.global_position.distance_to(closest_highlighted_target.global_position)

			# Check against ScannerManager's range before initiating
			if ScannerManager and dist <= ScannerManager.SCAN_RANGE:
				# print("PlayerInteraction: Requesting scan for ", closest_highlighted_target.name)
				ScannerManager.start_scan(closest_highlighted_target)
				get_viewport().set_input_as_handled() # Consume the input event
			# else:
				# print("PlayerInteraction: Target too far to initiate scan.")
				# Optional: Show feedback message via HUDManager.show_message(...)
		# else:
			# print("PlayerInteraction: No valid target highlighted to scan.")
			# Optional: Play a "cannot scan" sound effect


# Use physics process to regularly check which nearby object is closest
func _physics_process(delta: float) -> void:
	# Don't bother checking if player isn't controllable (e.g., scanning, dialogue)
	# Or if there are no potentially scannable objects nearby
	if not GameManager.is_player_controllable() or overlapping_scannables.is_empty():
		# If we lose control or have no overlaps, ensure nothing stays highlighted
		if is_instance_valid(closest_highlighted_target):
			_turn_off_highlight(closest_highlighted_target)
			closest_highlighted_target = null
		return

	# Find the new closest valid target and update highlighting
	_update_closest_highlight()


## Signal handler for when a ScanArea enters our InteractionArea
func _on_area_entered(area: Area3D) -> void:
	# The 'area' parameter is the ScannableObject's 'ScanArea'
	# We need the owner of that area, which is the ScannableObject (StaticBody3D) itself
	var owner_node = area.owner
	# Check if it's a valid ScannableObject (has the is_scanned method)
	if owner_node and owner_node.has_method("is_scanned"):
		if not owner_node in overlapping_scannables:
			overlapping_scannables.append(owner_node)
			# Don't highlight immediately, let _physics_process decide closest


## Signal handler for when a ScanArea exits our InteractionArea
func _on_area_exited(area: Area3D) -> void:
	var owner_node = area.owner
	# Check if it's a valid ScannableObject we were tracking
	if owner_node and owner_node.has_method("is_scanned"):
		if owner_node in overlapping_scannables:
			overlapping_scannables.erase(owner_node)
			# If this specific object *was* the one being highlighted, turn it off immediately
			if closest_highlighted_target == owner_node:
				_turn_off_highlight(owner_node)
				closest_highlighted_target = null
				# _physics_process will find a new closest next frame if available


## Recalculates the closest valid scannable and updates highlights accordingly.
func _update_closest_highlight() -> void:
	var new_closest_target = _get_closest_scannable_in_list()

	# Check if the closest target has changed
	if new_closest_target != closest_highlighted_target:
		# Turn off highlight on the previously closest object (if any)
		if is_instance_valid(closest_highlighted_target):
			_turn_off_highlight(closest_highlighted_target)

		# Turn on highlight on the newly closest object (if any)
		if is_instance_valid(new_closest_target):
			_turn_on_highlight(new_closest_target)

		# Update our tracked highlighted object
		closest_highlighted_target = new_closest_target


## Iterates through the current overlap list to find the nearest valid target.
func _get_closest_scannable_in_list() -> Node: # Returns ScannableObject (Node3D) or null
	var closest_dist_sq: float = INF
	var target_node = null
	var player_body = get_parent() as Node3D
	if not player_body: return null # Cannot calculate distance without player body

	var player_pos = player_body.global_position

	# Iterate backwards for safe removal
	for i in range(overlapping_scannables.size() - 1, -1, -1):
		var obj = overlapping_scannables[i]

		# Cleanup invalid instances from the list
		if not is_instance_valid(obj):
			overlapping_scannables.remove_at(i)
			continue

		# Skip if already scanned (using the object's own method)
		if obj.is_scanned():
			continue

		# Calculate distance and find the minimum
		var dist_sq = player_pos.distance_squared_to(obj.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			target_node = obj

	return target_node


# --- Helper Methods for Highlighting ---

## Calls the highlight method on the target ScannableObject.
func _turn_on_highlight(target: Node) -> void:
	# Check method existence for safety, although expected
	if target.has_method("highlight_in_range"):
		target.highlight_in_range(true)

## Calls the highlight method on the target ScannableObject.
func _turn_off_highlight(target: Node) -> void:
	if target.has_method("highlight_in_range"):
		target.highlight_in_range(false)

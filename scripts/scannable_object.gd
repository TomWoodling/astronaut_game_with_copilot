extends StaticBody3D
class_name ScannableObject

@export var collection_data: CollectionItemData
@export var scan_difficulty: float = 0.0  # 0.0 to 1.0

@onready var scan_highlight: OmniLight3D = $ScanHighlight
@onready var scan_indicator: GPUParticles3D = $ScanIndicator
@onready var object_mesh: Node3D = $scannable_object
@onready var scan_area: Area3D = $ScanArea
@onready var scan_shape: CollisionShape3D = $ScanArea/CollisionShape3D



var has_been_scanned: bool = false
var in_range: bool = false

func _ready() -> void:
	# CRITICAL: Validate essential components ONCE during setup.
	if not collection_data:
		push_error("ScannableObject '%s' is missing required CollectionItemData resource!" % name)
		# Prevent further issues by disabling interactions if data is missing.
		set_process(false)
		set_physics_process(false)
		scan_area = $ScanArea as Area3D
		if scan_area:
			scan_area.monitorable = false
			scan_area.monitoring = false
		return

	# --- Apply initial configuration based on trusted collection_data ---

	# Rotate non-biological items randomly (trusting 'category' exists)
	# Category enum: EXOBOTANY=0, EXOGEOLOGY=1, EXOBIOLOGY=2, ARTIFACTS=3
	if collection_data.category != 2:
		# Trusting object_mesh was found by @onready
		object_mesh.global_rotation.y = randf_range(0, TAU)

	# Create our Scan area collision shape:
	var new_shape : SphereShape3D = SphereShape3D.new()
	scan_shape.shape = new_shape
	var shape := scan_shape.shape
	if shape is SphereShape3D:
		var unique_shape := shape.duplicate() as SphereShape3D
		scan_shape.shape = unique_shape  # Assign the unique copy back
		unique_shape.radius = 6.0
		scan_shape.global_transform.origin = self.global_transform.origin
	else:
		push_warning("Collision shape is not a SphereShape3D")
	# Apply default material if flagged (trusting 'is_default' exists)
	if collection_data.is_default:
		# Find the specific MeshInstance3D node. This path might need adjustment
		# depending on your scene structure (e.g., $scannable_object/MeshInstance3D).
		# Using find_child as a fallback if direct path fails.
		var mesh_inst = object_mesh.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if not mesh_inst: mesh_inst = find_child("MeshInstance3D", true, false) as MeshInstance3D

		if mesh_inst: # Check if mesh_inst was found successfully
			if mesh_inst.get_surface_override_material(0) == null:
				var default_mat := StandardMaterial3D.new()
				default_mat.albedo_color = Color(0.7, 0.7, 0.8)
				default_mat.metallic = 0.3
				default_mat.roughness = 0.7
				mesh_inst.set_surface_override_material(0, default_mat)
		else:
			push_warning("ScannableObject '%s': Could not find MeshInstance3D to apply default material." % name)


	# Ensure visuals are initially off (trusting nodes were found by @onready)
	scan_highlight.visible = false
	scan_indicator.emitting = false
	scan_indicator.visible = false


# --- Public Methods ---

## Called by PlayerInteraction to toggle the highlight.
func highlight_in_range(is_in_range: bool) -> void:
	# Show highlight only if in range AND not yet scanned.
	scan_highlight.visible = is_in_range and not has_been_scanned

## Called by ScannerManager to start the particle effect.
func start_scan_effect() -> void:
	scan_indicator.visible = true
	scan_indicator.emitting = true

## Called by ScannerManager to stop the particle effect.
func stop_scan_effect() -> void:
	scan_indicator.emitting = false
	# scan_indicator.visible = false # Optional: Hide immediately

## Called by ScannerManager to get data and mark as scanned.
func get_scan_data() -> Dictionary:
	if not has_been_scanned:
		has_been_scanned = true
		highlight_in_range(false) # Ensure visuals are turned off
		stop_scan_effect()

	# Construct data dictionary (trusting collection_data properties exist)
	var data := {
		"id": collection_data.id,
		"category": collection_data.category,
		"label": collection_data.label,
		"description": collection_data.description,
		"rarity_tier": collection_data.rarity_tier,
		"timestamp": Time.get_unix_time_from_system(),
		"location": global_position,
	}
	return data

## Called by ScannerManager to calculate scan time.
func get_scan_difficulty() -> float:
	return scan_difficulty

## Called by PlayerInteraction to check if already scanned.
func is_scanned() -> bool:
	return has_been_scanned

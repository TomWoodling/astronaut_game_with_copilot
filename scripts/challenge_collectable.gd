# challenge_collectable.gd
extends StaticBody3D

signal collected(item_id: String)

# Element and appearance properties
@export var element_name: String = "Carbon"
@export var element_symbol: String = "C"
@export var element_color: Color = Color(0.3, 0.3, 0.3)
@export_enum("Sphere", "Cube", "Cylinder", "Prism", "Torus", "Pyramid", "Star", "HalfSphere", "Diamond", "Octahedron", "NiobiumSpecial") var shape_type: int = 0
@export var item_id: String = ""
@export var pulse_on_proximity: bool = true
@export var highlight_color: Color = Color(0.2, 0.8, 1.0)

# Visual components
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var scan_highlight: OmniLight3D = $ScanHighlight
@onready var particles: GPUParticles3D = $ElementParticles
@onready var element_label: Label3D = $ElementLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer


# Constants
const HOVER_HEIGHT: float = 0.2
const ROTATION_SPEED: float = 1.0
const COLLECT_EFFECT_DURATION: float = 1.5

# State
var can_collect: bool = true
var player_in_range: bool = false
var base_position: Vector3
var collected_by_player: bool = false
var atomic_number: int = 0
var atomic_sizes: Dictionary = {
	"H": 0.5, "He": 0.5, "C": 0.7, "N": 0.7, "O": 0.7, 
	"Si": 0.8, "P": 0.8, "Fe": 0.9, "Al": 0.85, "Mg": 0.85,
	"Nb": 1.0
}

# Terraforming elements data
var terraforming_elements: Dictionary = {
	"Carbon": {"symbol": "C", "atomic_number": 6, "color": Color(0.2, 0.2, 0.2)},
	"Nitrogen": {"symbol": "N", "atomic_number": 7, "color": Color(0.2, 0.2, 0.8)},
	"Oxygen": {"symbol": "O", "atomic_number": 8, "color": Color(0.8, 0.2, 0.2)},
	"Hydrogen": {"symbol": "H", "atomic_number": 1, "color": Color(0.9, 0.9, 0.9)},
	"Silicon": {"symbol": "Si", "atomic_number": 14, "color": Color(0.6, 0.6, 0.8)},
	"Phosphorus": {"symbol": "P", "atomic_number": 15, "color": Color(1.0, 0.5, 0.0)},
	"Iron": {"symbol": "Fe", "atomic_number": 26, "color": Color(0.6, 0.3, 0.1)},
	"Aluminium": {"symbol": "Al", "atomic_number": 13, "color": Color(0.75, 0.75, 0.75)},
	"Magnesium": {"symbol": "Mg", "atomic_number": 12, "color": Color(0.8, 0.8, 0.2)},
	"Helium": {"symbol": "He", "atomic_number": 2, "color": Color(0.9, 0.7, 0.2)},
	"Niobium": {"symbol": "Nb", "atomic_number": 41, "color": Color(0.4, 0.0, 0.8)}
}

func _ready() -> void:
	# Set unique identifier if not provided
	if item_id.is_empty():
		item_id = element_name + "_" + str(randi())
	
	# Set element data if it's one of our terraforming elements
	if terraforming_elements.has(element_name):
		var element_data = terraforming_elements[element_name]
		element_symbol = element_data.symbol
		atomic_number = element_data.atomic_number
		element_color = element_data.color
	
	# Initialize the mesh shape based on selection
	_update_mesh_shape()
	
	# Set mesh color
	_update_material()
	
	# Save initial position for hover effect
	base_position = position
	
	# Set up element label
	element_label.text = element_symbol
	element_label.modulate = Color.WHITE
	
	# Connect area signals if we have an area
	var collection_area = $CollectionArea
	if collection_area:
		collection_area.area_entered.connect(_on_collection_area_area_entered)
		collection_area.area_exited.connect(_on_collection_area_area_exited)

func _process(delta: float) -> void:
	if collected_by_player:
		return
	
	# Simple hover effect
	var hover_offset = sin(Time.get_ticks_msec() * 0.002) * HOVER_HEIGHT
	position.y = base_position.y + hover_offset
	
	# Rotation effect
	mesh_instance.rotate_y(delta * ROTATION_SPEED)
	
	# Particle effects based on element
	if particles and particles.visible:
		# Could adjust particle effects based on element properties
		pass

func _update_mesh_shape() -> void:
	# Create mesh based on selected shape
	var new_mesh: Mesh
	var new_collision_shape: Shape3D
	
	# Scale factor based on atomic number
	var scale_factor = 0.6 + min(atomic_number * 0.02, 1.0)
	
	match shape_type:
		0: # Sphere
			new_mesh = SphereMesh.new()
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.5 * scale_factor
		1: # Cube
			new_mesh = BoxMesh.new()
			new_collision_shape = BoxShape3D.new()
			new_collision_shape.size = Vector3.ONE * scale_factor
		2: # Cylinder
			new_mesh = CylinderMesh.new()
			new_collision_shape = CylinderShape3D.new()
			new_collision_shape.height = 1.0 * scale_factor
			new_collision_shape.radius = 0.5 * scale_factor
		3: # Prism
			new_mesh = PrismMesh.new()
			new_collision_shape = BoxShape3D.new()
			new_collision_shape.size = Vector3(1.0, 1.0, 1.0) * scale_factor
		4: # Torus
			new_mesh = TorusMesh.new()
			new_mesh.inner_radius = 0.3 * scale_factor
			new_mesh.outer_radius = 0.6 * scale_factor
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.6 * scale_factor
		5: # Pyramid - using PrismMesh with adjustments
			new_mesh = PrismMesh.new()
			var prism = new_mesh as PrismMesh
			prism.size = Vector3(1.0, 1.0, 1.0) * scale_factor
			new_collision_shape = BoxShape3D.new()
			new_collision_shape.size = Vector3(1.0, 1.0, 1.0) * scale_factor
		6: # Star - approximated with custom mesh
			# In a real implementation, you would create a custom star mesh
			new_mesh = SphereMesh.new()
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.6 * scale_factor
		7: # Half Sphere
			new_mesh = SphereMesh.new()
			var sphere = new_mesh as SphereMesh
			sphere.height = 0.5
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.5 * scale_factor
		8: # Diamond
			new_mesh = PrismMesh.new()
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.5 * scale_factor
		9: # Octahedron - approximated with multiple prisms
			new_mesh = SphereMesh.new() # Placeholder
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.5 * scale_factor
		10: # Niobium Special
			# Create a special mesh for Niobium that looks distinct
			new_mesh = SphereMesh.new()
			new_collision_shape = SphereShape3D.new()
			new_collision_shape.radius = 0.7
			
			# Add glow effect and particles
			scan_highlight.visible = true
			scan_highlight.light_color = Color(0.4, 0.0, 0.8, 1.0)
			if particles:
				particles.emitting = true
	
	# Apply the new mesh
	mesh_instance.mesh = new_mesh
	collision_shape.shape = new_collision_shape

func _update_material() -> void:
	# Create a new material for the mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = element_color
	material.metallic = 0.7  # Make it look a bit metallic
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = element_color * 0.3
	
	# Apply the material
	mesh_instance.material_override = material

func _on_collection_area_area_entered(area: Area3D) -> void:
	print(area)
	if area.is_in_group("player") and can_collect:
		print("player inside")
		MissionManager.mission_interactable = self
		player_in_range = true
		if pulse_on_proximity:
			animation_player.play("pulse")
			scan_highlight.visible = true

func _on_collection_area_area_exited(area: Area3D) -> void:
	if area.is_in_group("player"):
		player_in_range = false
		if pulse_on_proximity:
			animation_player.stop()
			scan_highlight.visible = false

func collect() -> void:
	if not can_collect or collected_by_player:
		return
	print("try collect")
	collected_by_player = true
	can_collect = false
	
	# Play collection effect
	if animation_player.has_animation("collect"):
		animation_player.play("collect")
	else:
		# Default collection effect
		scan_highlight.visible = true
		scan_highlight.light_energy = 2.0
		if particles:
			particles.emitting = true
	
	# Emit collection signal
	emit_signal("collected", item_id)
	
	# Schedule for removal
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.1,0.1,0.1), COLLECT_EFFECT_DURATION)
	tween.tween_callback(queue_free)

func interact() -> void:
	if player_in_range and can_collect:
		collect()

# This function can be called to set element by name
func set_element(name: String) -> void:
	if terraforming_elements.has(name):
		element_name = name
		var element_data = terraforming_elements[name]
		element_symbol = element_data.symbol
		atomic_number = element_data.atomic_number
		element_color = element_data.color
		
		# Update visuals
		_update_material()
		element_label.text = element_symbol
		
		# If it's Niobium, set special shape
		if name == "Niobium":
			shape_type = 10
			_update_mesh_shape()

func is_scanned() -> bool:
	# This always returns false to ensure the interaction system 
	# considers this object interactable
	return false

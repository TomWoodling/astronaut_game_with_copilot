# challenge_generator.gd
extends Node

# Reference to element shape mapping from EncounterManager
var element_shape_mapping: Dictionary = {
	"Carbon": 0,     # Sphere
	"Nitrogen": 2,   # Cylinder
	"Oxygen": 0,     # Sphere
	"Hydrogen": 0,   # Sphere
	"Silicon": 1,    # Cube
	"Phosphorus": 5, # Pyramid
	"Iron": 1,       # Cube
	"Aluminum": 3,   # Prism
	"Magnesium": 4,  # Torus
	"Helium": 0,     # Sphere
	"Niobium": 10    # Niobium Special
}

# Generate challenge objects for a collection challenge
func generate_collection_challenge(params: Dictionary) -> Array:
	var collectibles = []
	
	# Extract parameters with defaults
	var count = params.get("count", 1)
	var spawn_radius = params.get("spawn_radius", 10.0)
	var center_position = params.get("center_position", Vector3.ZERO)
	var element_types = params.get("element_types", ["Carbon", "Oxygen", "Hydrogen"])
	
	# Ensure we have valid elements
	if element_types.size() == 0:
		element_types = ["Carbon"]
	
	# Spawn collectible items
	for i in range(count):
		# Get a random position within the spawn radius
		var random_angle = randf() * 2.0 * PI
		var random_distance = randf() * spawn_radius
		var random_position = center_position + Vector3(
			cos(random_angle) * random_distance,
			0.5, # Float slightly above ground
			sin(random_angle) * random_distance
		)
		
		# Select a random element type from our list
		var element_name = element_types[randi() % element_types.size()]
		
		# Create collectible
		var collectible = preload("res://scenes/challenge_collectable.tscn").instantiate()
		
		# Set element properties
		collectible.set_element(element_name)
		
		# Set shape type based on element mapping (if available)
		if element_shape_mapping.has(element_name):
			collectible.shape_type = element_shape_mapping[element_name]
		
		# Set unique item_id for identification
		collectible.item_id = element_name + "_" + str(randi())
		
		# Enable pulse on proximity for better visibility
		collectible.pulse_on_proximity = true
		
		# Set global position
		collectible.global_position = random_position
		
		collectibles.append(collectible)
	
	return collectibles

# Generate a destination marker for platforming challenges
func generate_destination_marker(params: Dictionary) -> Node3D:
	var destination = preload("res://scenes/destination_marker.tscn").instantiate()
	
	# Set destination position
	var dest_pos = params.get("destination_position", Vector3.ZERO)
	destination.global_position = dest_pos
	
	return destination

# Validate challenge generation parameters
func validate_challenge_params(challenge_type: String, params: Dictionary) -> bool:
	match challenge_type:
		"COLLECTION":
			# Check required parameters for collection challenge
			return (params.has("count") and 
					params.has("spawn_radius") and 
					params.has("center_position"))
		"PLATFORMING":
			# Check required parameters for platforming challenge
			return params.has("destination_position")
		_:
			# Unknown challenge type
			push_error("Unknown challenge type: " + challenge_type)
			return false

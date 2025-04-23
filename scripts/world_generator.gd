extends Node3D

# Add Scannable Selector
@onready var scannable_selector: ScannableSelector = ScannableSelector.new()

# Terrain Generation Constants
const CHUNK_SIZE: int = 100
const TERRAIN_HEIGHT_RANGE: Vector2 = Vector2(-4.0, 4.5)
const NOISE_PARAMS = {
	"frequency": 0.005,
	"terrain_scale": 10.0,
	"detail_scale": 2.0
}

# New constants for terrain features
const FEATURE_TYPES = {
	"NONE": 0,
	"MOUNTAIN": 1,
	"CRATER": 2,
	"RIVERBED": 3,
	"CREVICE": 4
}

const FEATURE_PARAMS = {
	"MOUNTAIN": {
		"height": 15.0,
		"radius": 40.0,
		"roughness": 0.4
	},
	"CRATER": {
		"depth": 8.0,
		"radius": 30.0,
		"rim_height": 2.0
	},
	"RIVERBED": {
		"depth": 3.0,
		"width": 15.0,
		"meander": 0.2
	},
	"CREVICE": {
		"depth": 10.0,
		"width": 5.0,
		"length": 40.0
	}
}

# Feature placement per chunk
var chunk_features = {}

# Scannable object constant
const SCANNABLE_SPAWN_CONFIG = {
	"per_chunk": {
		"min": 2,
		"max": 4
	},
	"min_spacing": 15.0,  # Minimum distance between scannable objects
	"height_offset": 0.1   # How far above terrain to spawn
}

# Internal state
var noise: FastNoiseLite
var detail_noise: FastNoiseLite
var generated_chunks: Dictionary = {}
var current_chunk: Vector2i
var player: Node3D
var terrain_height_cache = {}
# Add a work queue
var chunk_generation_queue = []
var is_generating = false

@onready var scannable_object: PackedScene = preload("res://scenes/objects/basic_tree.tscn")

func _ready() -> void:
	# Initialize the scannable selector
	add_child(scannable_selector)
	
	setup_noise()
	await get_tree().process_frame
	initialize_world()

func get_terrain_height_range() -> Vector2:
	return TERRAIN_HEIGHT_RANGE

func _physics_process(_delta: float) -> void:
	if not player:
		return
		
	var player_chunk := get_chunk_coords(player.global_position)
	if current_chunk != player_chunk:
		check_chunks(player.global_position)

func setup_noise() -> void:
	# Main terrain noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = NOISE_PARAMS.frequency
	
	# Detail noise for added variation
	detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = randi() + 1  # Different seed for variation
	detail_noise.frequency = NOISE_PARAMS.frequency * 2.0  # Higher frequency for details

func initialize_world() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		push_error("WorldGenerator: Player node not found or is not Node3D. Make sure player is in the 'player' group.")
		return
	
	current_chunk = get_chunk_coords(Vector3.ZERO)
	check_chunks(Vector3.ZERO)

func get_chunk_coords(pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(pos.x / CHUNK_SIZE),
		floori(pos.z / CHUNK_SIZE)
	)

func queue_chunk_generation(chunk_coords: Vector2i) -> void:
	if not generated_chunks.has(chunk_coords) and not chunk_coords in chunk_generation_queue:
		chunk_generation_queue.append(chunk_coords)
		
	if not is_generating:
		call_deferred("process_chunk_queue")

func process_chunk_queue() -> void:
	is_generating = true
	
	if chunk_generation_queue.size() > 0:
		var coords = chunk_generation_queue.pop_front()
		generate_chunk(coords)
		call_deferred("process_chunk_queue")
	else:
		is_generating = false
		
func determine_chunk_feature(chunk_coords: Vector2i) -> Dictionary:
	# Use deterministic seeding based on chunk coordinates
	var feature_seed = noise.get_noise_2d(chunk_coords.x * 1000, chunk_coords.y * 1000)
	
	# 70% chance of no special feature
	if feature_seed > -0.3:
		return {"type": FEATURE_TYPES.NONE}
		
	# Determine feature type based on a different noise value
	var type_seed = noise.get_noise_2d(chunk_coords.x * 500, chunk_coords.y * 500)
	
	var feature = {}
	if type_seed < -0.6:
		feature.type = FEATURE_TYPES.CRATER
		feature.center = Vector2(
			randf_range(0.2, 0.8) * CHUNK_SIZE,
			randf_range(0.2, 0.8) * CHUNK_SIZE
		)
		feature.radius = randf_range(
			FEATURE_PARAMS.CRATER.radius * 0.6,
			FEATURE_PARAMS.CRATER.radius * 1.2
		)
	elif type_seed < -0.2:
		feature.type = FEATURE_TYPES.MOUNTAIN
		feature.center = Vector2(
			randf_range(0.2, 0.8) * CHUNK_SIZE,
			randf_range(0.2, 0.8) * CHUNK_SIZE
		)
		feature.radius = randf_range(
			FEATURE_PARAMS.MOUNTAIN.radius * 0.6,
			FEATURE_PARAMS.MOUNTAIN.radius * 1.2
		)
	elif type_seed < 0.2:
		feature.type = FEATURE_TYPES.RIVERBED
		# Rivers need start and end points
		feature.start = Vector2(0, randf_range(0.3, 0.7) * CHUNK_SIZE)
		feature.end = Vector2(CHUNK_SIZE, randf_range(0.3, 0.7) * CHUNK_SIZE)
	else:
		feature.type = FEATURE_TYPES.CREVICE
		# Crevices need direction and position
		feature.center = Vector2(
			randf_range(0.2, 0.8) * CHUNK_SIZE,
			randf_range(0.2, 0.8) * CHUNK_SIZE
		)
		feature.angle = randf_range(0, PI)
		
	return feature
	
func generate_chunk(chunk_coords: Vector2i) -> void:
	if generated_chunks.has(chunk_coords):
		return
		
	var chunk := Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_coords.x, chunk_coords.y]
	add_child(chunk)
	
	chunk.position = Vector3(
		chunk_coords.x * CHUNK_SIZE,
		0,
		chunk_coords.y * CHUNK_SIZE
	)
	
	var terrain := generate_terrain_mesh(chunk_coords)
	if terrain:
		chunk.add_child(terrain)
		spawn_scannable_objects(chunk, chunk_coords)
		generated_chunks[chunk_coords] = chunk
	else:
		chunk.queue_free()
		push_error("WorldGenerator: Failed to generate terrain for chunk %s" % chunk_coords)

func generate_terrain_mesh(chunk_coords: Vector2i) -> MeshInstance3D:
	# Create a plane mesh for the base
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane_mesh.subdivide_width = 32
	plane_mesh.subdivide_depth = 32
	
	# Create an ArrayMesh to modify
	var array_mesh := ArrayMesh.new()
	var surface_arrays := plane_mesh.surface_get_arrays(0)
	
	# Get vertices and modify their heights
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	var modified_vertices := PackedVector3Array()
	modified_vertices.resize(vertices.size())
	
	# Modify the height of each vertex
	for i in range(vertices.size()):
		var vertex := vertices[i]
		var world_pos := vertex + Vector3(chunk_coords.x * CHUNK_SIZE, 0, chunk_coords.y * CHUNK_SIZE)
		
		var height := get_height_at_point(world_pos)
		modified_vertices[i] = Vector3(vertex.x, height, vertex.z)
	
	# Replace the vertices in the surface arrays
	surface_arrays[Mesh.ARRAY_VERTEX] = modified_vertices
	
	# Add the modified surface to the array mesh
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	
	# Create the mesh instance
	var terrain := MeshInstance3D.new()
	terrain.mesh = array_mesh
	
	# Create a terrain material using the shader
	var feature = chunk_features[chunk_coords]
	var terrain_mat = create_terrain_material(chunk_coords, feature)
	
	terrain.material_override = terrain_mat
	
	# Add collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	
	# Create a concave collision shape from the mesh
	var shape := array_mesh.create_trimesh_shape()
	collision_shape.shape = shape
	
	static_body.add_child(collision_shape)
	terrain.add_child(static_body)
	
	return terrain

# Updated terrain material creation function
func create_terrain_material(chunk_coords: Vector2i, feature: Dictionary) -> ShaderMaterial:
	var terrain_shader = load("res://assets/mats/terrain_shader.gdshader")
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = terrain_shader
	
	# Set base shader parameters
	shader_mat.set_shader_parameter("terrain_height_min", TERRAIN_HEIGHT_RANGE.x)
	shader_mat.set_shader_parameter("terrain_height_max", TERRAIN_HEIGHT_RANGE.y)
	
	# Set feature-specific parameters
	match feature.type:
		FEATURE_TYPES.MOUNTAIN:
			shader_mat.set_shader_parameter("primary_color", Color(0.5, 0.5, 0.5))
			shader_mat.set_shader_parameter("feature_center", Vector2(
				feature.center.x + chunk_coords.x * CHUNK_SIZE,
				feature.center.y + chunk_coords.y * CHUNK_SIZE
			))
			shader_mat.set_shader_parameter("feature_radius", feature.radius)
			shader_mat.set_shader_parameter("feature_type", FEATURE_TYPES.MOUNTAIN)
			
		FEATURE_TYPES.CRATER:
			shader_mat.set_shader_parameter("primary_color", Color(0.7, 0.6, 0.5))
			shader_mat.set_shader_parameter("feature_center", Vector2(
				feature.center.x + chunk_coords.x * CHUNK_SIZE,
				feature.center.y + chunk_coords.y * CHUNK_SIZE
			))
			shader_mat.set_shader_parameter("feature_radius", feature.radius)
			shader_mat.set_shader_parameter("feature_type", FEATURE_TYPES.CRATER)
			
		FEATURE_TYPES.RIVERBED:
			shader_mat.set_shader_parameter("primary_color", Color(0.6, 0.6, 0.8))
			shader_mat.set_shader_parameter("river_start", Vector2(
				feature.start.x + chunk_coords.x * CHUNK_SIZE,
				feature.start.y + chunk_coords.y * CHUNK_SIZE
			))
			shader_mat.set_shader_parameter("river_end", Vector2(
				feature.end.x + chunk_coords.x * CHUNK_SIZE,
				feature.end.y + chunk_coords.y * CHUNK_SIZE
			))
			shader_mat.set_shader_parameter("river_width", FEATURE_PARAMS.RIVERBED.width)
			shader_mat.set_shader_parameter("feature_type", FEATURE_TYPES.RIVERBED)
			
		FEATURE_TYPES.CREVICE:
			shader_mat.set_shader_parameter("primary_color", Color(0.3, 0.3, 0.35))
			shader_mat.set_shader_parameter("feature_center", Vector2(
				feature.center.x + chunk_coords.x * CHUNK_SIZE,
				feature.center.y + chunk_coords.y * CHUNK_SIZE
			))
			shader_mat.set_shader_parameter("feature_angle", feature.angle)
			shader_mat.set_shader_parameter("feature_length", FEATURE_PARAMS.CREVICE.length)
			shader_mat.set_shader_parameter("feature_width", FEATURE_PARAMS.CREVICE.width)
			shader_mat.set_shader_parameter("feature_type", FEATURE_TYPES.CREVICE)
			
		_:
			shader_mat.set_shader_parameter("primary_color", Color(0.3, 0.7, 0.2))
			shader_mat.set_shader_parameter("feature_type", FEATURE_TYPES.NONE)
	
	# Set shared parameters for blending between different terrain types
	shader_mat.set_shader_parameter("noise_seed", noise.seed)
	shader_mat.set_shader_parameter("noise_frequency", NOISE_PARAMS.frequency)
	
	return shader_mat

func get_height_at_point(world_pos: Vector3) -> float:
	# Get chunk coordinates for this position
	var chunk_coords = get_chunk_coords(world_pos)
	
	# Calculate base height using existing noise
	var base_height := noise.get_noise_2d(world_pos.x, world_pos.z)
	var detail := detail_noise.get_noise_2d(world_pos.x * 2.0, world_pos.z * 2.0)
	
	# Remap from [-1,1] to our height range
	var combined := base_height * NOISE_PARAMS.terrain_scale + detail * NOISE_PARAMS.detail_scale
	var remapped := lerpf(TERRAIN_HEIGHT_RANGE.x, TERRAIN_HEIGHT_RANGE.y, (combined + 1.0) / 2.0)
	
	# Get chunk-local coordinates
	var local_x = world_pos.x - (chunk_coords.x * CHUNK_SIZE)
	var local_z = world_pos.z - (chunk_coords.y * CHUNK_SIZE)
	var local_pos = Vector2(local_x, local_z)
	
	# Apply feature modification if this chunk has a feature
	if not chunk_features.has(chunk_coords):
		chunk_features[chunk_coords] = determine_chunk_feature(chunk_coords)
		
	var feature = chunk_features[chunk_coords]
	
	match feature.type:
		FEATURE_TYPES.MOUNTAIN:
			var distance = local_pos.distance_to(feature.center)
			if distance < feature.radius:
				# Apply mountain height based on distance from center
				var factor = 1.0 - (distance / feature.radius)
				factor = pow(factor, 2)  # Square for steeper mountains
				var mountain_height = FEATURE_PARAMS.MOUNTAIN.height * factor
				
				# Add some noise to the mountain shape
				var mountain_noise = noise.get_noise_2d(
					world_pos.x * 0.1, 
					world_pos.z * 0.1
				) * FEATURE_PARAMS.MOUNTAIN.roughness
				
				remapped += mountain_height + (mountain_noise * factor * 2.0)
				
		FEATURE_TYPES.CRATER:
			var distance = local_pos.distance_to(feature.center)
			if distance < feature.radius:
				# Create crater depression with raised rim
				var normalized_dist = distance / feature.radius
				var crater_factor = 0.0
				
				if normalized_dist > 0.8:
					# Create rim (0.8-1.0 radius range)
					var rim_factor = (normalized_dist - 0.8) / 0.2
					crater_factor = sin(rim_factor * PI) * FEATURE_PARAMS.CRATER.rim_height
				else:
					# Crater bowl shape
					crater_factor = -FEATURE_PARAMS.CRATER.depth * (1.0 - pow(normalized_dist, 0.5))
				
				remapped += crater_factor
				
		FEATURE_TYPES.RIVERBED:
			# Calculate closest distance to the river path
			var river_path = Curve2D.new()
			river_path.add_point(feature.start)
			# Add some meandering control points
			var control_points = 3
			for i in range(control_points):
				var t = (i + 1.0) / (control_points + 1.0)
				var mid = feature.start.lerp(feature.end, t)
				var offset = Vector2(
					randf_range(-1, 1) * FEATURE_PARAMS.RIVERBED.meander * CHUNK_SIZE,
					randf_range(-1, 1) * FEATURE_PARAMS.RIVERBED.meander * CHUNK_SIZE
				)
				river_path.add_point(mid + offset)
			river_path.add_point(feature.end)
			
			var closest_point = river_path.get_closest_point(local_pos)
			var distance = local_pos.distance_to(closest_point)
			
			if distance < FEATURE_PARAMS.RIVERBED.width:
				var factor = 1.0 - (distance / FEATURE_PARAMS.RIVERBED.width)
				factor = smoothstep(0, 1, factor)  # Smooth edges
				remapped -= FEATURE_PARAMS.RIVERBED.depth * factor
			
		FEATURE_TYPES.CREVICE:
			# Calculate distance to crevice line
			var crevice_dir = Vector2(cos(feature.angle), sin(feature.angle))
			var to_point = local_pos - feature.center
			var proj = to_point.dot(crevice_dir)
			var perp = (to_point - crevice_dir * proj).length()
			
			# Only modify within length and width
			if abs(proj) < FEATURE_PARAMS.CREVICE.length * 0.5 and perp < FEATURE_PARAMS.CREVICE.width:
				var factor = 1.0 - (perp / FEATURE_PARAMS.CREVICE.width)
				factor = pow(factor, 2)  # Sharper drop
				remapped -= FEATURE_PARAMS.CREVICE.depth * factor
	
	return remapped

func spawn_scannable_objects(chunk: Node3D, chunk_coords: Vector2i) -> void:
	var num_objects := randi_range(
		SCANNABLE_SPAWN_CONFIG.per_chunk.min, 
		SCANNABLE_SPAWN_CONFIG.per_chunk.max
	)
	
	var placed_positions: Array[Vector3] = []
	var attempts := 0
	var max_attempts := num_objects * 4  # Prevent infinite loops
	
	while placed_positions.size() < num_objects and attempts < max_attempts:
		var pos := Vector3(
			randf_range(0, CHUNK_SIZE),
			0,
			randf_range(0, CHUNK_SIZE)
		)
		
		# Check minimum spacing
		var valid_position := true
		for placed in placed_positions:
			if pos.distance_to(placed) < SCANNABLE_SPAWN_CONFIG.min_spacing:
				valid_position = false
				break
		
		if valid_position:
			var world_pos := pos + Vector3(
				chunk_coords.x * CHUNK_SIZE,
				0,
				chunk_coords.y * CHUNK_SIZE
			)
			
			# Set Y position based on terrain height
			var terrain_height = get_height_at_point(world_pos)
			pos.y = terrain_height + SCANNABLE_SPAWN_CONFIG.height_offset
			
			# Get appropriate scannable for this location
			var object_scene = scannable_selector.get_scannable_for_location(world_pos, terrain_height)
			var object = object_scene.instantiate()
			
			object.position = pos
			chunk.add_child(object)
			placed_positions.append(pos)
		
		attempts += 1

func check_chunks(player_pos: Vector3) -> void:
	current_chunk = get_chunk_coords(player_pos)
	
	# Use a view distance constant for easier configuration
	const VIEW_DISTANCE = 1  # Current value is 1 chunk radius
	
	# Generate surrounding chunks
	for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for y in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			var check_coords := current_chunk + Vector2i(x, y)
			if not generated_chunks.has(check_coords):
				generate_chunk(check_coords)
	
	# Clean up distant chunks
	var chunks_to_remove: Array[Vector2i] = []
	for coords in generated_chunks:
		if abs(coords.x - current_chunk.x) > VIEW_DISTANCE or abs(coords.y - current_chunk.y) > VIEW_DISTANCE:
			chunks_to_remove.append(coords)
	
	# Consider a priority queue approach for chunk generation based on distance

func _exit_tree() -> void:
	# Clean up noise resources
	if noise:
		noise.free()
	if detail_noise:
		detail_noise.free()
		
	# Clean up chunks
	for chunk in generated_chunks.values():
		if is_instance_valid(chunk) and chunk.is_inside_tree():
			chunk.queue_free()
	generated_chunks.clear()

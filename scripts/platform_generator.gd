extends Node3D

# Enum for path generation algorithms
enum PathAlgorithm {
	LINEAR,           # Simple linear interpolation
	PERLIN_NOISE,     # Organic, natural-feeling paths
	SPIRAL,           # Gradually expanding spiral
	SINE_WAVE,        # Sinusoidal path with controllable amplitude
	FRACTAL_TERRAIN   # Complex, terrain-like path generation
}

# Advanced block generation parameters
@export_group("Block Course Generation")
@export var start_point: Vector3 = Vector3.ZERO
@export var end_point: Vector3 = Vector3(20, 0, 20)
@export var waypoints: PackedVector3Array = []
@export var block_count: int = 10
@export var spacing_variance: float = 0.5
@export var size_variance: float = 0.3
@export var collision_padding: float = 1.0  # Minimum distance between blocks

# Path generation options
@export_group("Path Generation")
@export var path_algorithm: PathAlgorithm = PathAlgorithm.LINEAR
@export var noise_scale: float = 5.0  # For Perlin noise path
@export var spiral_turns: float = 2.0  # For spiral path
@export var sine_amplitude: float = 2.0  # For sine wave path
@export var fractal_roughness: float = 0.5  # For fractal terrain path

# Block size and color configurations
@export_group("Block Sizes")
@export var min_block_width: float = 2.0
@export var max_block_width: float = 6.0
@export var min_block_length: float = 2.0
@export var max_block_length: float = 6.0
@export var block_height: float = 0.5

@export_group("Block Colors")
@export_enum("Blue", "Green", "Red", "Yellow") var color_theme: int = 0

const BLOCK_COLORS = {
	0: Color(0.2, 0.4, 0.8, 1),    # Blue
	1: Color(0.3, 0.7, 0.3, 1),    # Green
	2: Color(0.8, 0.2, 0.2, 1),    # Red
	3: Color(0.9, 0.7, 0.2, 1)     # Yellow
}

var generated_blocks: Array[MeshInstance3D] = []

func _ready():
	#generate_blocks()
	pass
func generate_path(total_blocks: int) -> PackedVector3Array:
	var path_points: PackedVector3Array
	
	match path_algorithm:
		PathAlgorithm.LINEAR:
			path_points = generate_linear_path(total_blocks)
		PathAlgorithm.PERLIN_NOISE:
			path_points = generate_perlin_noise_path(total_blocks)
		PathAlgorithm.SPIRAL:
			path_points = generate_spiral_path(total_blocks)
		PathAlgorithm.SINE_WAVE:
			path_points = generate_sine_wave_path(total_blocks)
		PathAlgorithm.FRACTAL_TERRAIN:
			path_points = generate_fractal_path(total_blocks)
	
	return path_points

func generate_linear_path(total_blocks: int) -> PackedVector3Array:
	var path: PackedVector3Array = [start_point]
	path.append_array(waypoints)
	path.append(end_point)
	
	var interpolated_path: PackedVector3Array = []
	for i in range(path.size() - 1):
		var segment_start = path[i]
		var segment_end = path[i + 1]
		
		for j in range(total_blocks / path.size()):
			var t = float(j) / (total_blocks / path.size() - 1)
			interpolated_path.append(segment_start.lerp(segment_end, t))
	
	return interpolated_path

func generate_perlin_noise_path(total_blocks: int) -> PackedVector3Array:
	var path: PackedVector3Array = []
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale
	
	var direction = (end_point - start_point).normalized()
	var perp_vector = direction.cross(Vector3.UP).normalized()
	
	for i in range(total_blocks):
		var t = float(i) / (total_blocks - 1)
		var base_point = start_point.lerp(end_point, t)
		
		var noise_value = noise.get_noise_1d(i * 10.0)
		var offset = noise_value * 3.0
		
		path.append(base_point + perp_vector * offset)
	
	return path

func generate_spiral_path(total_blocks: int) -> PackedVector3Array:
	var path: PackedVector3Array = []
	var direction = (end_point - start_point).normalized()
	var total_distance = start_point.distance_to(end_point)
	
	for i in range(total_blocks):
		var t = float(i) / (total_blocks - 1)
		var angle = t * spiral_turns * TAU
		var radius = t * total_distance / (2 * PI)
		
		var spiral_offset = Vector3(
			cos(angle) * radius, 
			0, 
			sin(angle) * radius
		)
		
		path.append(start_point + direction * t * total_distance + spiral_offset)
	
	return path

func generate_sine_wave_path(total_blocks: int) -> PackedVector3Array:
	var path: PackedVector3Array = []
	var direction = (end_point - start_point).normalized()
	var perp_vector = direction.cross(Vector3.UP).normalized()
	var total_distance = start_point.distance_to(end_point)
	
	for i in range(total_blocks):
		var t = float(i) / (total_blocks - 1)
		var base_point = start_point.lerp(end_point, t)
		var sine_offset = sin(t * TAU) * sine_amplitude
		
		path.append(base_point + perp_vector * sine_offset)
	
	return path

func generate_fractal_path(total_blocks: int) -> PackedVector3Array:
	# Midpoint displacement algorithm for terrain-like paths
	var path: PackedVector3Array = [start_point, end_point]
	
	for depth in range(int(log(total_blocks) / log(2))):
		var new_path: PackedVector3Array = []
		for j in range(path.size() - 1):
			var midpoint = (path[j] + path[j+1]) / 2.0
			var displacement = randf_range(-fractal_roughness, fractal_roughness)
			midpoint.y += displacement
			
			new_path.append(path[j])
			new_path.append(midpoint)
		
		new_path.append(path[-1])
		path = new_path
	
	# Resample to exact block count
	var resampled_path: PackedVector3Array = []
	for i in range(total_blocks):
		var t = float(i) / (total_blocks - 1)
		var index = int(t * (path.size() - 1))
		resampled_path.append(path[index])
	
	return resampled_path

func is_block_collision(new_block: MeshInstance3D) -> bool:
	for existing_block in generated_blocks:
		if existing_block.position.distance_to(new_block.position) < collision_padding:
			return true
	return false

func generate_blocks():
	# Clear existing blocks
	for child in get_children():
		child.queue_free()
	generated_blocks.clear()
	
	# Generate path points
	var block_positions = generate_path(block_count)
	
	# Generate blocks with collision detection
	for pos in block_positions:
		var mesh_instance = MeshInstance3D.new()
		var cube_mesh = BoxMesh.new()
		
		# Randomize block dimensions with size variance
		var block_width = randf_range(
			min_block_width * (1 - size_variance), 
			max_block_width * (1 + size_variance)
		)
		var block_length = randf_range(
			min_block_length * (1 - size_variance), 
			max_block_length * (1 + size_variance)
		)
		
		cube_mesh.size = Vector3(block_width, block_height, block_length)
		
		var material = StandardMaterial3D.new()
		material.albedo_color = BLOCK_COLORS[color_theme]
		
		mesh_instance.mesh = cube_mesh
		mesh_instance.material_override = material
		
		# Add variance and collision detection
		var attempts = 0
		while attempts < 10:
			var position_variance = Vector3(
				randf_range(-spacing_variance, spacing_variance),
				randf_range(-spacing_variance, spacing_variance),
				randf_range(-spacing_variance, spacing_variance)
			)
			mesh_instance.position = pos + position_variance
			
			if !is_block_collision(mesh_instance):
				add_child(mesh_instance)
				mesh_instance.create_convex_collision(false,true)
				generated_blocks.append(mesh_instance)
				break
			
			attempts += 1

func initialize_level():
	print("Advanced level blocks initialized")

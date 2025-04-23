@tool
extends EditorPlugin

const PLUGIN_NAME = "InteriorCaveGenerator"

var dock
var cave_generator
var preview_mesh_instance

func _enter_tree():
	# Create the cave generator
	cave_generator = InteriorCaveGenerator.new()
	add_child(cave_generator)
	
	# Create the dock
	dock = preload("res://addons/interior_cave_generator/cave_generator_dock.tscn").instantiate()
	dock.cave_generator = cave_generator
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	# Connect signals
	dock.connect("generate_preview", Callable(self, "_on_generate_preview"))
	dock.connect("apply_cave", Callable(self, "_on_apply_cave"))

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	if cave_generator:
		cave_generator.queue_free()
		
	if preview_mesh_instance and is_instance_valid(preview_mesh_instance):
		preview_mesh_instance.queue_free()

func _on_generate_preview():
	if preview_mesh_instance and is_instance_valid(preview_mesh_instance):
		preview_mesh_instance.queue_free()
	
	preview_mesh_instance = MeshInstance3D.new()
	preview_mesh_instance.mesh = cave_generator.generate_cave_mesh()
	preview_mesh_instance.material_override = cave_generator.create_cave_material()
	
	# Add to scene
	get_editor_interface().get_edited_scene_root().add_child(preview_mesh_instance)
	preview_mesh_instance.owner = get_editor_interface().get_edited_scene_root()

func _on_apply_cave():
	if not preview_mesh_instance or not is_instance_valid(preview_mesh_instance):
		return
		
	# Convert preview to static mesh with collision
	var static_body = StaticBody3D.new()
	static_body.name = "InteriorCave"
	
	# Remove preview from current parent
	var parent = preview_mesh_instance.get_parent()
	if parent:
		parent.remove_child(preview_mesh_instance)
	
	# Add the static body to the scene first
	get_editor_interface().get_edited_scene_root().add_child(static_body)
	static_body.owner = get_editor_interface().get_edited_scene_root()
	
	# Now add the mesh instance to the static body
	static_body.add_child(preview_mesh_instance)
	preview_mesh_instance.owner = get_editor_interface().get_edited_scene_root()
	
	# Create and add collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = preview_mesh_instance.mesh.create_trimesh_shape()
	static_body.add_child(collision_shape)
	collision_shape.owner = get_editor_interface().get_edited_scene_root()
	
	# Add floor if specified
	if cave_generator.add_floor:
		var floor_mesh = cave_generator.generate_floor_mesh()
		var floor_instance = MeshInstance3D.new()
		floor_instance.name = "Floor"
		floor_instance.mesh = floor_mesh
		floor_instance.material_override = cave_generator.create_floor_material()
		
		static_body.add_child(floor_instance)
		floor_instance.owner = get_editor_interface().get_edited_scene_root()
		
		# Add floor collision
		var floor_collision = CollisionShape3D.new()
		floor_collision.shape = floor_mesh.create_trimesh_shape()
		floor_collision.name = "FloorCollision"
		static_body.add_child(floor_collision)
		floor_collision.owner = get_editor_interface().get_edited_scene_root()
	
	# Reset reference so we don't delete it on next preview
	preview_mesh_instance = null

class InteriorCaveGenerator:
	extends Node
	
	enum PRIMITIVE_TYPE {
		CYLINDER,
		CONE,
		SPHERE,
		CAPSULE,
		TORUS
	}
	
	enum NOISE_TYPE {
		PERLIN,
		SIMPLEX,
		CELLULAR,
		VALUE
	}
	
	# Base shape parameters
	var primitive_type: int = PRIMITIVE_TYPE.CYLINDER
	var width: float = 10.0
	var height: float = 25.0
	var depth: float = 10.0  # Used for non-radial primitives
	var radial_segments: int = 64
	var rings: int = 32
	
	# Noise parameters
	var noise_type: int = NOISE_TYPE.PERLIN
	var noise_amplitude: float = 1.5
	var noise_frequency: float = 0.2
	var noise_seed: int = 0
	var noise_octaves: int = 3
	var noise_lacunarity: float = 2.0
	var noise_gain: float = 0.5
	
	# Floor options
	var add_floor: bool = true
	var floor_height: float = 0.0
	var floor_roughness: float = 0.2
	
	# Material options
	var wall_color: Color = Color(0.5, 0.5, 0.6)
	var floor_color: Color = Color(0.4, 0.4, 0.45)
	var roughness: float = 0.9
	
	var noise: FastNoiseLite
	
	func _init():
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = noise_seed
		noise.frequency = noise_frequency
		noise.fractal_octaves = noise_octaves
		noise.fractal_lacunarity = noise_lacunarity
		noise.fractal_gain = noise_gain
	
	func set_primitive_type(type: int):
		primitive_type = type
		# Set appropriate defaults based on shape
		match type:
			PRIMITIVE_TYPE.CYLINDER:
				radial_segments = 64
				rings = 8
			PRIMITIVE_TYPE.CONE:
				radial_segments = 64
				rings = 1
			PRIMITIVE_TYPE.SPHERE:
				radial_segments = 64
				rings = 32
			PRIMITIVE_TYPE.CAPSULE:
				radial_segments = 64
				rings = 8
			PRIMITIVE_TYPE.TORUS:
				radial_segments = 64
				rings = 32
	
	func set_noise_type(type: int):
		noise_type = type
		match type:
			NOISE_TYPE.PERLIN:
				noise.noise_type = FastNoiseLite.TYPE_PERLIN
			NOISE_TYPE.SIMPLEX:
				noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			NOISE_TYPE.CELLULAR:
				noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			NOISE_TYPE.VALUE:
				noise.noise_type = FastNoiseLite.TYPE_VALUE
	
	func set_preset(preset_name: String):
		match preset_name:
			"Small Chamber":
				primitive_type = PRIMITIVE_TYPE.CYLINDER
				width = 10.0
				height = 15.0
				noise_amplitude = 1.0
				noise_frequency = 0.2
				add_floor = true
				floor_roughness = 0.1
			"Large Cavern":
				primitive_type = PRIMITIVE_TYPE.SPHERE
				width = 25.0
				height = 25.0
				noise_amplitude = 3.0
				noise_frequency = 0.15
				add_floor = true
				floor_roughness = 0.3
			"Tunnel Section":
				primitive_type = PRIMITIVE_TYPE.CYLINDER
				width = 6.0
				height = 40.0
				noise_amplitude = 0.8
				noise_frequency = 0.25
				add_floor = false
			"Cenote":
				primitive_type = PRIMITIVE_TYPE.CYLINDER
				width = 15.0
				height = 30.0
				noise_amplitude = 2.0
				noise_frequency = 0.1
				add_floor = true
				floor_height = -5.0
				floor_roughness = 0.5
			"Underground Dome":
				primitive_type = PRIMITIVE_TYPE.SPHERE
				width = 20.0
				height = 20.0
				noise_amplitude = 1.5
				noise_frequency = 0.15
				add_floor = true
				floor_height = -8.0
				floor_roughness = 0.2
	
	func generate_cave_mesh() -> ArrayMesh:
		# Update noise parameters
		noise.seed = noise_seed
		noise.frequency = noise_frequency
		noise.fractal_octaves = noise_octaves
		noise.fractal_lacunarity = noise_lacunarity
		noise.fractal_gain = noise_gain
		
		# Create array mesh
		var array_mesh = ArrayMesh.new()
		
		# Generate the appropriate shape directly as an array mesh
		var surface_arrays = []
		match primitive_type:
			PRIMITIVE_TYPE.CYLINDER:
				surface_arrays = _generate_cylinder_arrays(width/2.0, height, radial_segments, rings)
			PRIMITIVE_TYPE.CONE:
				surface_arrays = _generate_cone_arrays(width/2.0, height, radial_segments, rings)
			PRIMITIVE_TYPE.SPHERE:
				surface_arrays = _generate_sphere_arrays(width/2.0, radial_segments, rings)
			PRIMITIVE_TYPE.CAPSULE:
				surface_arrays = _generate_capsule_arrays(width/2.0, height, radial_segments, rings)
			PRIMITIVE_TYPE.TORUS:
				surface_arrays = _generate_torus_arrays(width/4.0, width/2.0, radial_segments, rings)
		
		var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = surface_arrays[Mesh.ARRAY_NORMAL]
		var modified_vertices = PackedVector3Array()
		modified_vertices.resize(vertices.size())
		
		# Process each vertex - add noise
		for i in range(vertices.size()):
			var vertex = vertices[i]
			var normal = normals[i]
			
			# Get noise value based on position
			var noise_value = noise.get_noise_3d(
				vertex.x * noise_frequency * 10.0,
				vertex.y * noise_frequency * 10.0,
				vertex.z * noise_frequency * 10.0
			)
			
			# Apply noise along normal direction (outward for interior carving)
			var noise_offset = normal * noise_value * noise_amplitude
			var modified_vertex = vertex + noise_offset
			
			modified_vertices[i] = modified_vertex
		
		# Replace vertices in surface arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = modified_vertices
		
		# Add surface to array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		
		return array_mesh
	
	# Generate a horizontal cylinder along the Z-axis
	func _generate_cylinder_arrays(radius: float, length: float, radial_segments: int, rings: int) -> Array:
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		# Generate vertices
		for ring in range(rings + 1):
			var z = (float(ring) / rings) * length - (length / 2)
			
			for segment in range(radial_segments + 1):
				var angle = 2.0 * PI * segment / radial_segments
				var x = radius * cos(angle)
				var y = radius * sin(angle)
				
				# Add vertex
				vertices.append(Vector3(x, y, z))
				
				# Add normal pointing inward for interior viewing
				normals.append(Vector3(-x/radius, -y/radius, 0).normalized())
				
				# Add UV
				uvs.append(Vector2(float(segment) / radial_segments, float(ring) / rings))
		
		# Generate indices (triangles)
		for ring in range(rings):
			for segment in range(radial_segments):
				var current = ring * (radial_segments + 1) + segment
				var next_segment = ring * (radial_segments + 1) + segment + 1
				var next_ring = (ring + 1) * (radial_segments + 1) + segment
				var next_ring_segment = (ring + 1) * (radial_segments + 1) + segment + 1
				
				# First triangle (oriented for interior viewing)
				indices.append(current)
				indices.append(next_ring)
				indices.append(next_segment)
				
				# Second triangle (oriented for interior viewing)
				indices.append(next_segment)
				indices.append(next_ring)
				indices.append(next_ring_segment)
		
		# Assign arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		return surface_arrays
	
	# Generate a horizontal cone along the Z-axis
	func _generate_cone_arrays(radius: float, length: float, radial_segments: int, rings: int) -> Array:
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		# Generate vertices
		for ring in range(rings + 1):
			var z = (float(ring) / rings) * length - (length / 2)
			var current_radius = radius * (1.0 - float(ring) / rings)
			
			for segment in range(radial_segments + 1):
				var angle = 2.0 * PI * segment / radial_segments
				var x = current_radius * cos(angle)
				var y = current_radius * sin(angle)
				
				# Add vertex
				vertices.append(Vector3(x, y, z))
				
				# Calculate normal - more complex for a cone
				var normal_x = -x
				var normal_y = -y
				var normal_z = radius / length
				var normal = Vector3(normal_x, normal_y, normal_z).normalized()
				if normal == Vector3.ZERO:  # Prevent zero normals
					normal = Vector3(0, 0, -1)
					
				# Invert for interior
				normals.append(-normal)
				
				# Add UV
				uvs.append(Vector2(float(segment) / radial_segments, float(ring) / rings))
		
		# Generate indices (triangles)
		for ring in range(rings):
			for segment in range(radial_segments):
				var current = ring * (radial_segments + 1) + segment
				var next_segment = ring * (radial_segments + 1) + segment + 1
				var next_ring = (ring + 1) * (radial_segments + 1) + segment
				var next_ring_segment = (ring + 1) * (radial_segments + 1) + segment + 1
				
				# First triangle (oriented for interior viewing)
				indices.append(current)
				indices.append(next_ring)
				indices.append(next_segment)
				
				# Second triangle (oriented for interior viewing)
				indices.append(next_segment)
				indices.append(next_ring)
				indices.append(next_ring_segment)
		
		# Assign arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		return surface_arrays
	
	# Generate a sphere
	func _generate_sphere_arrays(radius: float, longitude_segments: int, latitude_segments: int) -> Array:
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		for lat in range(latitude_segments + 1):
			var theta = lat * PI / latitude_segments
			var sin_theta = sin(theta)
			var cos_theta = cos(theta)
			
			for lon in range(longitude_segments + 1):
				var phi = lon * 2.0 * PI / longitude_segments
				var sin_phi = sin(phi)
				var cos_phi = cos(phi)
				
				var x = sin_theta * cos_phi
				var y = cos_theta
				var z = sin_theta * sin_phi
				
				# Add vertex
				vertices.append(Vector3(x, y, z) * radius)
				
				# Add normal pointing inward for interior viewing
				normals.append(Vector3(-x, -y, -z).normalized())
				
				# Add UV
				uvs.append(Vector2(float(lon) / longitude_segments, float(lat) / latitude_segments))
		
		# Generate indices
		for lat in range(latitude_segments):
			for lon in range(longitude_segments):
				var first = lat * (longitude_segments + 1) + lon
				var second = first + longitude_segments + 1
				
				# First triangle (oriented for interior viewing)
				indices.append(first)
				indices.append(second)
				indices.append(first + 1)
				
				# Second triangle (oriented for interior viewing)
				indices.append(first + 1)
				indices.append(second)
				indices.append(second + 1)
		
		# Assign arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		return surface_arrays
	
	# Generate a horizontal capsule along the Z-axis
	func _generate_capsule_arrays(radius: float, height: float, radial_segments: int, rings: int) -> Array:
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		var half_height = height / 2.0
		var cylinder_height = height - 2 * radius
		var half_cylinder_height = cylinder_height / 2.0
		
		# Generate vertices for the cylinder part and the two hemisphere caps
		for ring in range(rings + 1):
			var u = float(ring) / rings
			var z
			
			if ring <= rings / 3:  # First hemisphere
				var angle = u * PI / 2
				z = -half_cylinder_height - radius * cos(angle)
			elif ring >= 2 * rings / 3:  # Second hemisphere
				var angle = (u - 2.0/3.0) * 3.0 * PI / 2
				z = half_cylinder_height + radius * sin(angle)
			else:  # Cylinder part
				z = lerp(-half_cylinder_height, half_cylinder_height, (u - 1.0/3.0) * 3.0 / 2.0)
			
			for segment in range(radial_segments + 1):
				var v = float(segment) / radial_segments
				var angle = v * 2.0 * PI
				
				var x = radius * cos(angle)
				var y = radius * sin(angle)
				
				# Add vertex
				vertices.append(Vector3(x, y, z))
				
				# Calculate normal
				var normal
				if ring <= rings / 3:  # First hemisphere
					if z == -half_cylinder_height - radius:  # At pole
						normal = Vector3(0, 0, -1)
					else:
						normal = Vector3(x, y, z + half_cylinder_height).normalized()
				elif ring >= 2 * rings / 3:  # Second hemisphere
					if z == half_cylinder_height + radius:  # At pole
						normal = Vector3(0, 0, 1)
					else:
						normal = Vector3(x, y, z - half_cylinder_height).normalized()
				else:  # Cylinder part
					normal = Vector3(x, y, 0).normalized()
				
				# Invert for interior viewing
				normals.append(-normal)
				
				# Add UV
				uvs.append(Vector2(v, u))
		
		# Generate indices
		for ring in range(rings):
			for segment in range(radial_segments):
				var current = ring * (radial_segments + 1) + segment
				var next_segment = ring * (radial_segments + 1) + segment + 1
				var next_ring = (ring + 1) * (radial_segments + 1) + segment
				var next_ring_segment = (ring + 1) * (radial_segments + 1) + segment + 1
				
				# First triangle (oriented for interior viewing)
				indices.append(current)
				indices.append(next_ring)
				indices.append(next_segment)
				
				# Second triangle (oriented for interior viewing)
				indices.append(next_segment)
				indices.append(next_ring)
				indices.append(next_ring_segment)
		
		# Assign arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		return surface_arrays
	
	# Generate a torus
	func _generate_torus_arrays(inner_radius: float, outer_radius: float, segments: int, rings: int) -> Array:
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		for ring in range(rings + 1):
			var u = float(ring) / rings
			var phi = u * 2.0 * PI
			var cos_phi = cos(phi)
			var sin_phi = sin(phi)
			
			for segment in range(segments + 1):
				var v = float(segment) / segments
				var theta = v * 2.0 * PI
				var cos_theta = cos(theta)
				var sin_theta = sin(theta)
				
				# Calculate position
				var r = outer_radius + inner_radius * cos_theta
				var x = r * cos_phi
				var y = r * sin_phi
				var z = inner_radius * sin_theta
				
				vertices.append(Vector3(x, y, z))
				
				# Calculate normal - point inward for interior
				var cx = outer_radius * cos_phi  # Center of the small circle
				var cy = outer_radius * sin_phi
				var normal = Vector3(x - cx, y - cy, z).normalized()
				normals.append(-normal)
				
				uvs.append(Vector2(u, v))
		
		# Generate indices
		for ring in range(rings):
			for segment in range(segments):
				var current = ring * (segments + 1) + segment
				var next_segment = ring * (segments + 1) + segment + 1
				var next_ring = (ring + 1) * (segments + 1) + segment
				var next_ring_segment = (ring + 1) * (segments + 1) + segment + 1
				
				# First triangle (oriented for interior viewing)
				indices.append(current)
				indices.append(next_ring)
				indices.append(next_segment)
				
				# Second triangle (oriented for interior viewing)
				indices.append(next_segment)
				indices.append(next_ring)
				indices.append(next_ring_segment)
		
		# Assign arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		return surface_arrays
	
	func generate_floor_mesh() -> ArrayMesh:
		# Create a floor plane with noise
		var array_mesh = ArrayMesh.new()
		
		# Size based on cave dimensions
		var floor_size = max(width, depth) * 1.2
		var half_size = floor_size / 2.0
		
		# Create vertices for a simple grid
		var subdivisions = 32  # Higher for more detailed noise
		var step = floor_size / subdivisions
		
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		var uvs = PackedVector2Array()
		var indices = PackedInt32Array()
		
		# Generate grid of vertices
		for i in range(subdivisions + 1):
			for j in range(subdivisions + 1):
				var x = -half_size + i * step
				var z = -half_size + j * step
				
				# Add noise to floor height
				var noise_val = noise.get_noise_2d(
					x * noise_frequency * 5.0,
					z * noise_frequency * 5.0
				) * floor_roughness
				
				vertices.append(Vector3(x, floor_height + noise_val, z))
				normals.append(Vector3(0, 1, 0))  # Up-facing normal
				uvs.append(Vector2(float(i)/subdivisions, float(j)/subdivisions))
		
		# Generate indices for triangles
		for i in range(subdivisions):
			for j in range(subdivisions):
				var current = i * (subdivisions + 1) + j
				var next_col = current + 1
				var next_row = current + (subdivisions + 1)
				var next_row_col = next_row + 1
				
				# First triangle
				indices.append(current)
				indices.append(next_row)
				indices.append(next_col)
				
				# Second triangle
				indices.append(next_col)
				indices.append(next_row)
				indices.append(next_row_col)
		
		# Create surface arrays
		var surface_arrays = []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs
		surface_arrays[Mesh.ARRAY_INDEX] = indices
		
		# Add surface to array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		
		return array_mesh
	
	func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
		var normals = PackedVector3Array()
		normals.resize(vertices.size())
		
		# Initialize all normals to zero
		for i in range(normals.size()):
			normals[i] = Vector3.ZERO
		
		# Calculate normals for each face
		for i in range(0, indices.size(), 3):
			var a = vertices[indices[i]]
			var b = vertices[indices[i+1]]
			var c = vertices[indices[i+2]]
			
			var normal = (b - a).cross(c - a).normalized()
			
			# Add this normal to each vertex of the triangle
			normals[indices[i]] += normal
			normals[indices[i+1]] += normal
			normals[indices[i+2]] += normal
		
		# Normalize all normals
		for i in range(normals.size()):
			if normals[i] != Vector3.ZERO:
				normals[i] = normals[i].normalized()
			else:
				normals[i] = Vector3.UP
		
		return normals
	
	func create_cave_material() -> StandardMaterial3D:
		var material = StandardMaterial3D.new()
		material.albedo_color = wall_color
		material.roughness = roughness
		material.metallic_specular = 0.1
		
		#Since we're generating with correct normals, we can use standard culling
		material.cull_mode = StandardMaterial3D.CULL_FRONT
		
		return material
	
	func create_floor_material() -> StandardMaterial3D:
		var material = StandardMaterial3D.new()
		material.albedo_color = floor_color
		material.roughness = roughness
		material.metallic_specular = 0.1
		
		return material

@tool
extends EditorPlugin

const PLUGIN_NAME = "BoundedTerrainGenerator"

var dock
var terrain_generator
var preview_mesh_instance

func _enter_tree():
	# Create the terrain generator
	terrain_generator = BoundedTerrainGenerator.new()
	add_child(terrain_generator)
	
	# Create the dock
	dock = preload("res://addons/bounded_terrain_generator/terrain_generator_dock.tscn").instantiate()
	dock.terrain_generator = terrain_generator
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	
	# Connect signals
	dock.connect("generate_preview", Callable(self, "_on_generate_preview"))
	dock.connect("apply_terrain", Callable(self, "_on_apply_terrain"))

func _exit_tree():
	# Clean up
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	
	if terrain_generator:
		terrain_generator.queue_free()
		
	if preview_mesh_instance and is_instance_valid(preview_mesh_instance):
		preview_mesh_instance.queue_free()

func _on_generate_preview():
	if preview_mesh_instance and is_instance_valid(preview_mesh_instance):
		preview_mesh_instance.queue_free()
	
	preview_mesh_instance = MeshInstance3D.new()
	preview_mesh_instance.mesh = terrain_generator.generate_terrain_mesh()
	preview_mesh_instance.material_override = terrain_generator.create_terrain_material()
	
	get_editor_interface().get_edited_scene_root().add_child(preview_mesh_instance)
	preview_mesh_instance.owner = get_editor_interface().get_edited_scene_root()

func _on_apply_terrain():
	if not preview_mesh_instance or not is_instance_valid(preview_mesh_instance):
		return
		
	# Convert preview to static mesh with collision
	var static_body = StaticBody3D.new()
	static_body.name = "BoundedTerrain"
	
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
	
	# Reset reference so we don't delete it on next preview
	preview_mesh_instance = null

class BoundedTerrainGenerator:
	extends Node
	
	enum TERRAIN_TYPE {
		CRATER,
		CANYON,
		CAVE
	}
	
	# Current settings
	var current_type: int = TERRAIN_TYPE.CRATER
	var area_size: float = 100.0  # Base size (1 chunk)
	var num_chunks: int = 1       # How many chunks to span (1-6)
	var wall_height: float = 30.0
	var wall_steepness: float = 0.8  # 0-1 where 1 is vertical
	var floor_roughness: float = 0.2 # 0-1
	var floor_elevation: float = 0.0 # Base floor height
	var noise_seed: int = 0
	
	# Advanced settings
	var edge_noise: float = 0.1    # Randomness at boundaries
	var rim_height: float = 2.0    # Height of the rim (for craters)
	var direction: Vector2 = Vector2(1, 0)  # For directional features like canyons
	
	var noise: FastNoiseLite
	
	func _init():
		noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = noise_seed
		noise.frequency = 0.01
	
	func set_type(type: int):
		current_type = type
		# Apply type-specific default settings
		match type:
			TERRAIN_TYPE.CRATER:
				wall_steepness = 0.8
				floor_roughness = 0.3
				rim_height = 2.0
			TERRAIN_TYPE.CANYON:
				wall_steepness = 0.9
				floor_roughness = 0.4
				rim_height = 1.0
			TERRAIN_TYPE.CAVE:
				wall_steepness = 0.95
				floor_roughness = 0.2
				rim_height = 0.0
	
	func set_preset(preset_name: String):
		match preset_name:
			"Small Crater":
				current_type = TERRAIN_TYPE.CRATER
				area_size = 80.0
				num_chunks = 1
				wall_height = 25.0
				floor_roughness = 0.2
				edge_noise = 0.05
			"Large Impact Site":
				current_type = TERRAIN_TYPE.CRATER
				area_size = 120.0
				num_chunks = 3
				wall_height = 40.0
				floor_roughness = 0.4
				edge_noise = 0.2
				rim_height = 4.0
			"Narrow Canyon":
				current_type = TERRAIN_TYPE.CANYON
				area_size = 60.0
				num_chunks = 2
				wall_height = 35.0
				floor_roughness = 0.3
				direction = Vector2(1, 0)
			"Wide Valley":
				current_type = TERRAIN_TYPE.CANYON
				area_size = 150.0
				num_chunks = 4
				wall_height = 30.0
				floor_roughness = 0.5
				direction = Vector2(1, 1).normalized()
			"Small Cave":
				current_type = TERRAIN_TYPE.CAVE
				area_size = 50.0
				num_chunks = 1
				wall_height = 20.0
				wall_steepness = 0.95
				floor_roughness = 0.1
			"Large Cavern":
				current_type = TERRAIN_TYPE.CAVE
				area_size = 100.0
				num_chunks = 2
				wall_height = 35.0
				wall_steepness = 0.9
				floor_roughness = 0.3
	
	func generate_terrain_mesh() -> ArrayMesh:
		# Adjust effective size based on number of chunks
		var effective_size = area_size * sqrt(num_chunks)
		
		# Create base plane mesh
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(effective_size * 1.5, effective_size * 1.5)  # Extra space for walls
		plane_mesh.subdivide_width = 64
		plane_mesh.subdivide_depth = 64
		
		# Convert to array mesh for modification
		var array_mesh = ArrayMesh.new()
		var surface_arrays = plane_mesh.surface_get_arrays(0)
		
		var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
		var modified_vertices = PackedVector3Array()
		modified_vertices.resize(vertices.size())
		
		# Center of the terrain
		var center = Vector2(0, 0)
		
		# Update noise
		noise.seed = noise_seed
		
		# Process each vertex
		for i in range(vertices.size()):
			var vertex = vertices[i]
			var local_pos = Vector2(vertex.x, vertex.z)
			var height = 0.0
			
			match current_type:
				TERRAIN_TYPE.CRATER:
					height = _generate_crater_height(local_pos, center, effective_size)
				TERRAIN_TYPE.CANYON:
					height = _generate_canyon_height(local_pos, center, effective_size)
				TERRAIN_TYPE.CAVE:
					height = _generate_cave_height(local_pos, center, effective_size)
			
			# Apply floor roughness
			var base_noise = noise.get_noise_2d(vertex.x * 0.1, vertex.z * 0.1)
			height += base_noise * floor_roughness * 2.0
			
			modified_vertices[i] = Vector3(vertex.x, height + floor_elevation, vertex.z)
		
		# Replace vertices in surface arrays
		surface_arrays[Mesh.ARRAY_VERTEX] = modified_vertices
		
		# Recalculate normals
		surface_arrays[Mesh.ARRAY_NORMAL] = _calculate_normals(modified_vertices, surface_arrays[Mesh.ARRAY_INDEX])
		
		# Add modified surface to array mesh
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		
		return array_mesh
	
	func _generate_crater_height(pos: Vector2, center: Vector2, size: float) -> float:
		var distance = pos.distance_to(center)
		var radius = size * 0.5
		var height = 0.0
		
		if distance < radius:
			# Inside crater - relatively flat floor with noise
			var normalized_dist = distance / radius
			height = 0.0
		else:
			# Crater wall with rim
			var wall_factor = (distance - radius) / (radius * 0.5)
			wall_factor = clamp(wall_factor, 0.0, 1.0)
			
			# Create rim at edge
			var rim_factor = 0.0
			if wall_factor < 0.2:
				rim_factor = sin(wall_factor * 5.0 * PI) * rim_height
			
			# Create steep walls after rim
			if wall_factor > 0.1:
				var steep_factor = (wall_factor - 0.1) / 0.9
				steep_factor = pow(steep_factor, 1.0 / (1.0 - wall_steepness))
				height = steep_factor * wall_height
			
			height += rim_factor
			
			# Add edge noise
			var edge_variation = noise.get_noise_2d(pos.x * 0.05, pos.y * 0.05) * edge_noise * wall_height
			height += edge_variation
		
		return height
	
	func _generate_canyon_height(pos: Vector2, center: Vector2, size: float) -> float:
		# Calculate distance to canyon centerline
		var canyon_half_width = size * 0.25
		var canyon_direction = direction.normalized()
		var perp_direction = Vector2(-canyon_direction.y, canyon_direction.x)
		
		# Project point onto direction vector
		var to_point = pos - center
		var along_canyon = to_point.dot(canyon_direction)
		var across_canyon = abs(to_point.dot(perp_direction))
		
		var height = 0.0
		var max_length = size * 0.7
		
		if abs(along_canyon) < max_length and across_canyon < canyon_half_width:
			# Inside canyon - flat floor
			height = 0.0
		else:
			# Outside canyon - create walls
			var wall_factor = 0.0
			
			if across_canyon >= canyon_half_width:
				wall_factor = (across_canyon - canyon_half_width) / (canyon_half_width * 0.5)
				wall_factor = clamp(wall_factor, 0.0, 1.0)
			
			if abs(along_canyon) >= max_length:
				var end_factor = (abs(along_canyon) - max_length) / (max_length * 0.3)
				end_factor = clamp(end_factor, 0.0, 1.0)
				wall_factor = max(wall_factor, end_factor)
			
			# Create steep walls
			wall_factor = pow(wall_factor, 1.0 / (1.0 - wall_steepness))
			height = wall_factor * wall_height
			
			# Add edge noise
			var edge_variation = noise.get_noise_2d(pos.x * 0.05, pos.y * 0.05) * edge_noise * wall_height
			height += edge_variation
		
		return height
	
	func _generate_cave_height(pos: Vector2, center: Vector2, size: float) -> float:
		var distance = pos.distance_to(center)
		var radius = size * 0.4  # Cave is slightly smaller than crater
		var height = 0.0
		
		# For caves, we maintain a ceiling
		var ceiling_height = wall_height
		
		if distance < radius:
			# Inside cave - flat floor
			height = 0.0
		else:
			# Outside cave - create walls
			var wall_factor = (distance - radius) / (radius * 0.3)
			wall_factor = clamp(wall_factor, 0.0, 1.0)
			
			# Create steep walls
			wall_factor = pow(wall_factor, 1.0 / (1.0 - wall_steepness))
			height = wall_factor * wall_height
			
			# Add edge noise
			var edge_variation = noise.get_noise_2d(pos.x * 0.05, pos.y * 0.05) * edge_noise * wall_height
			height += edge_variation
		
		return height
	
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
	
	func create_terrain_material() -> StandardMaterial3D:
		var material = StandardMaterial3D.new()
		
		# Set base color based on terrain type
		match current_type:
			TERRAIN_TYPE.CRATER:
				material.albedo_color = Color(0.7, 0.6, 0.5)
			TERRAIN_TYPE.CANYON:
				material.albedo_color = Color(0.8, 0.6, 0.4)
			TERRAIN_TYPE.CAVE:
				material.albedo_color = Color(0.5, 0.5, 0.6)
		
		material.roughness = 0.9
		material.metallic_specular = 0.1
		
		return material

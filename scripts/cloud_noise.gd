@tool
extends Node

# This script generates a noise texture for clouds that can be used by our sky shader

@export var texture_size = 512
@export var generate_texture: bool = false:
	set(value):
		if value:
			_generate_cloud_texture()

@export_file("*.res") var save_path = "res://assets/mats/cloud_noise.tres"

func _generate_cloud_texture() -> void:
	var img = Image.create(texture_size, texture_size, false, Image.FORMAT_RGBAF)
	var noise = FastNoiseLite.new()
	
	# First layer: Base noise
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = 0.005
	
	# Second layer: Detail noise
	var detail_noise = FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = randi()
	detail_noise.frequency = 0.02
	
	# Generate the noise
	#img.lock()
	for x in range(texture_size):
		for y in range(texture_size):
			var base = (noise.get_noise_2d(x, y) * 0.5 + 0.5)
			var detail = (detail_noise.get_noise_2d(x, y) * 0.5 + 0.5)
			
			# Combine the noise layers
			var combined = base * 0.7 + detail * 0.3
			
			# Apply some contrast
			combined = pow(combined, 1.5)
			
			# Set the pixel
			img.set_pixel(x, y, Color(combined, combined, combined, 1.0))
	#img.unlock()
	
	# Create and save the texture
	var texture = ImageTexture.create_from_image(img)
	
	# Save the texture resource
	if ResourceSaver.save(texture, save_path) == OK:
		print("Cloud noise texture saved to: " + save_path)
	else:
		push_error("Failed to save cloud noise texture!")

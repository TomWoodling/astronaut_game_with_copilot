extends Node3D

@onready var player: Node3D = $player
@onready var sun: DirectionalLight3D = $DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment

# Sky shader properties
var exoplanet_sky_material: ShaderMaterial
var cloud_noise_texture: Texture2D
var time_of_day: float = 0.3  # 0.0 = midnight, 0.5 = noon, 1.0 = midnight again
var day_duration: float = 600.0  # seconds for a full day cycle

var is_planet_nearby: bool = false
var is_high_end_device: bool = true  # Placeholder for device performance

func _ready() -> void:
	print("World scene ready.")

	# 1. Set the player reference in GameManager (going to try setting this directly in player_movement)
	# GameManager.player = player
	# print("World: Player reference set in GameManager.")

	# Create a completely new environment
	create_environment()
	
	# Apply all settings to the new environment
	setup_sky_shader()
	apply_environment_settings()
	setup_advanced_effects()
	print("Environment applied: ", env.background_mode == Environment.BG_SKY)
	print("Sky material applied: ", env.sky and env.sky.sky_material == exoplanet_sky_material)
	print("Cloud texture applied: ", exoplanet_sky_material.get_shader_parameter("cloud_noise_texture") == cloud_noise_texture)
	_remove_holding_area()
	call_deferred("_enter_playing_state")


func _enter_playing_state() -> void:
	# Ensure player starts controllable
	GameManager.set_gameplay_state(GameManager.GameplayState.NORMAL)
	# Change overall game state
	GameManager.change_game_state(GameManager.GameState.PLAYING)
	print("World: GameState set to PLAYING.")
	# Set mouse mode for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	# Update time of day if day/night cycle is enabled
	time_of_day += delta / day_duration
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	
	# Update sky based on time of day
	update_sky(time_of_day)
	
	# Update environment settings based on time of day
	update_environment(time_of_day)

func create_environment() -> void:
	# Find or create WorldEnvironment node
	world_env = $WorldEnvironment
	
	# Create a new Environment resource
	env = Environment.new()
	
	# Set it as the environment for our WorldEnvironment node
	if world_env:
		world_env.environment = env
		print("Applied new environment to existing WorldEnvironment node")
	else:
		# If no WorldEnvironment node exists, create one
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		world_env.environment = env
		add_child(world_env)
		print("Created new WorldEnvironment node")
	
	# Set basic environment properties
	env.background_mode = Environment.BG_SKY
	print("New environment created successfully")

func setup_sky_shader() -> void:
	# Create a new sky
	var sky = Sky.new()
	exoplanet_sky_material = ShaderMaterial.new()
	
	# Load the shader
	var shader = load("res://assets/mats/exoplanet_sky.gdshader")
	if not shader:
		push_error("Failed to load exoplanet sky shader!")
		return
		
	exoplanet_sky_material.shader = shader
	
	# Load cloud noise texture
	cloud_noise_texture = load("res://assets/mats/cloud_noise.tres")
	if not cloud_noise_texture:
		push_warning("Cloud noise texture not found! Sky clouds will not render correctly.")
	else:
		exoplanet_sky_material.set_shader_parameter("cloud_noise_texture", cloud_noise_texture)
	
	# Set initial shader parameters
	exoplanet_sky_material.set_shader_parameter("sky_top_color", Color(0.1, 0.25, 0.4))
	exoplanet_sky_material.set_shader_parameter("sky_horizon_color", Color(0.5, 0.7, 0.65))
	exoplanet_sky_material.set_shader_parameter("sky_bottom_color", Color(0.2, 0.3, 0.5))
	exoplanet_sky_material.set_shader_parameter("sky_horizon_blend", 0.1)
	exoplanet_sky_material.set_shader_parameter("sky_curve", 1.5)
	exoplanet_sky_material.set_shader_parameter("sun_color", Color(1.5, 1.2, 0.8))
	exoplanet_sky_material.set_shader_parameter("second_sun_color", Color(1.0, 0.5, 0.3))
	exoplanet_sky_material.set_shader_parameter("sun_size", 0.2)
	exoplanet_sky_material.set_shader_parameter("sun_blur", 0.5)
	exoplanet_sky_material.set_shader_parameter("second_sun_size", 0.1)
	exoplanet_sky_material.set_shader_parameter("cloud_coverage", 0.6)
	exoplanet_sky_material.set_shader_parameter("cloud_thickness", 2.2)
	exoplanet_sky_material.set_shader_parameter("cloud_color1", Color(0.95, 1.0, 0.98))
	exoplanet_sky_material.set_shader_parameter("cloud_color2", Color(0.8, 0.85, 0.9))
	exoplanet_sky_material.set_shader_parameter("cloud_speed", 0.003)
	exoplanet_sky_material.set_shader_parameter("enable_aurora", true)
	exoplanet_sky_material.set_shader_parameter("aurora_color1", Color(0.1, 0.8, 0.3))
	exoplanet_sky_material.set_shader_parameter("aurora_color2", Color(0.3, 0.3, 0.8))
	exoplanet_sky_material.set_shader_parameter("aurora_intensity", 1.0)
	exoplanet_sky_material.set_shader_parameter("aurora_speed", 0.5)
	exoplanet_sky_material.set_shader_parameter("enable_stars", true)
	exoplanet_sky_material.set_shader_parameter("star_intensity", 0.3)
	
	# Set initial sun direction based on time of day
	update_sun_direction(time_of_day)
	
	# Assign the material to the sky
	sky.sky_material = exoplanet_sky_material
	env.sky = sky
	
	print("Exoplanet sky shader set up successfully.")

func update_environment(time: float) -> void:
	if not env:
		return
		
	# Calculate day factor (-1 to 1, where 0 is noon, -1 is midnight)
	var day_factor = sin(time * TAU)
	
	# Adjust ambient light based on time of day
	var ambient_energy = remap(day_factor, -1.0, 1.0, 0.2, 0.8)
	env.ambient_light_energy = ambient_energy
	
	# Adjust sky contribution to ambient based on time
	env.ambient_light_sky_contribution = remap(day_factor, -1.0, 1.0, 0.3, 0.7)
	
	# Adjust tonemap exposure (brighter during day, darker at night)
	env.tonemap_exposure = remap(day_factor, -1.0, 1.0, 1.2, 0.9)
	
	# Glow is more pronounced at night
	env.glow_intensity = remap(day_factor, -1.0, 1.0, 0.8, 0.5)
	
	# Adjust volumetric fog properties for day/night effect
	var fog_density = remap(day_factor, -1.0, 1.0, 0.03, 0.02)
	env.volumetric_fog_density = fog_density
	
	# Fog color more bluish at night, slight green tint during day (alien atmosphere)
	if day_factor > 0:
		# Day
		env.volumetric_fog_albedo = Color(0.1, 0.15, 0.12)
	else:
		# Night
		env.volumetric_fog_albedo = Color(0.08, 0.08, 0.18)
	
	# SSAO more pronounced during night for more dramatic shadows
	env.ssao_intensity = remap(day_factor, -1.0, 1.0, 2.5, 1.8)

func update_sky(time: float) -> void:
	if not exoplanet_sky_material:
		return
		
	# Update sun direction based on time
	update_sun_direction(time)
	
	# Update sky colors based on time of day
	var day_factor = sin(time * TAU)
	
	# Adjust sky colors for day/night cycle
	if day_factor > 0:
		# Day
		var top_color = Color(0.1, 0.2, 0.4)
		var horizon_color = Color(0.5, 0.7, 0.8)
		exoplanet_sky_material.set_shader_parameter("sky_top_color", top_color)
		exoplanet_sky_material.set_shader_parameter("sky_horizon_color", horizon_color)
		
		# Make stars less visible during day
		exoplanet_sky_material.set_shader_parameter("star_intensity", 0.05)
	else:
		# Night
		var top_color = Color(0.02, 0.05, 0.1)
		var horizon_color = Color(0.1, 0.12, 0.15)
		exoplanet_sky_material.set_shader_parameter("sky_top_color", top_color)
		exoplanet_sky_material.set_shader_parameter("sky_horizon_color", horizon_color)
		
		# Stars more visible at night
		exoplanet_sky_material.set_shader_parameter("star_intensity", 0.3)
	
	# Enable/disable aurora based on time (only at night)
	exoplanet_sky_material.set_shader_parameter("enable_aurora", day_factor < 0)

func update_sun_direction(time: float) -> void:
	if not exoplanet_sky_material or not sun:
		return
		
	# Calculate sun angle based on time of day
	var sun_angle = time * TAU
	var sun_dir = Vector3(sin(sun_angle), sin(sun_angle * 2.0) * 0.3 + 0.4, -cos(sun_angle)).normalized()
	
	# Set the sun direction in the shader
	exoplanet_sky_material.set_shader_parameter("sun_direction", sun_dir)
	
	# Second sun is offset from the first
	var second_sun_dir = Vector3(sun_dir.x * 0.8, sun_dir.y * 0.5, sun_dir.z * 0.7).normalized()
	exoplanet_sky_material.set_shader_parameter("second_sun_direction", second_sun_dir)
	
	# Update the directional light to match the primary sun
	sun.rotation = Vector3(-sun_dir.y, -sun_dir.x, sun_dir.z).normalized()
	
	# Adjust sun energy based on height
	var sun_height = sun_dir.y
	sun.light_energy = max(0.0, sun_height) * 1.5
	
	# Adjust light color based on height (redder near horizon)
	if sun_height > 0:
		if sun_height < 0.2:
			# Sunrise/sunset
			sun.light_color = Color(1.0, 0.6, 0.3)
		else:
			# Day
			sun.light_color = Color(1.0, 0.98, 0.88)
	else:
		# Night
		sun.light_energy = 0.2  # Moonlight
		sun.light_color = Color(0.6, 0.6, 0.8)  # Bluish night light

func apply_environment_settings() -> void:
	# Fog settings - keeping as they are per your request
	env.fog_enabled = true
	env.fog_density = 0.03
	env.fog_sky_affect = 0.1
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.1, 0.1, 0.15)
	
	# Enhanced ambient light - slight color tint for alien feel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.ambient_light_energy = 0.8
	
	# Shadow settings
	if sun:
		sun.shadow_enabled = true
		sun.shadow_bias = 0.03
		sun.directional_shadow_max_distance = 300.0
	
	# SSAO settings for more realistic terrain depth
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.0
	env.ssao_power = 1.8
	env.ssao_detail = 1.0
	env.ssao_horizon = 0.08
	env.ssao_sharpness = 0.98
	
	# Tonemap settings for alien atmosphere
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 1.0
	
	# Glow settings for atmospheric effect
	env.glow_enabled = true
	env.set_glow_level(0,0.0)
	env.set_glow_level(1,0.3)
	env.set_glow_level(2,1.0)
	env.set_glow_level(3,0.5)
	env.set_glow_level(4,0.2)
	env.set_glow_level(5,0.0)
	env.set_glow_level(6,0.0)
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.2
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	print("Enhanced environment settings applied for terraforming exoplanet.")

func setup_advanced_effects() -> void:
	# Adjustments based on planet proximity
	if is_planet_nearby:
		env.fog_density = 0.05
		env.volumetric_fog_density = 0.04
		
		# Make aurora more visible near planet
		if exoplanet_sky_material:
			exoplanet_sky_material.set_shader_parameter("aurora_intensity", 1.5)
	else:
		# Default settings for space
		if exoplanet_sky_material:
			exoplanet_sky_material.set_shader_parameter("aurora_intensity", 0.8)

	# Device performance adjustments
	if not is_high_end_device:
		env.ssao_enabled = false
		env.glow_enabled = false
		print("Low-end device detected: Disabling SSAO and glow.")
	else:
		print("High-end device detected: Applying full effects.")

	print("Advanced effects applied.")

func _remove_holding_area():
	# Remove the temporary holding area once the world is generated
	var holding_area = $holdingArea
	if holding_area:
		# Wait a short moment to ensure world generation has started
		await get_tree().create_timer(0.5).timeout
		holding_area.queue_free()

func remap(value: float, from_low: float, from_high: float, to_low: float, to_high: float) -> float:
	return (value - from_low) / (from_high - from_low) * (to_high - to_low) + to_low

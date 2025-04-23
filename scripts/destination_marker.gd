# destination_marker.gd
extends StaticBody3D

signal reached

# Appearance properties
@export var marker_color: Color = Color(0.2, 0.8, 0.2)
@export var pulse_intensity: float = 1.0
@export var particle_count: int = 64
@export var marker_radius: float = 2.0
@export_enum("Destination", "Checkpoint", "Quest", "Formula", "Laboratory") var marker_type: int = 0
@export var auto_rotate: bool = true
@export var rotation_speed: float = 0.5

# Visual components
@onready var particles: GPUParticles3D = $MarkerParticles
@onready var light: OmniLight3D = $MarkerLight
@onready var mesh_instance: MeshInstance3D = $MarkerMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioPlayer
@onready var marker_area: Area3D = $MarkerArea

# Constants
const PLAYER_GROUP: String = "player"
const REACHED_EFFECT_DURATION: float = 2.0

# State
var is_active: bool = true
var player_in_range: bool = false
var was_reached: bool = false

func _ready() -> void:
	# Set up visuals based on marker type
	_configure_marker_type()
	
	# Apply color
	_update_colors()
	
	# Set up area collision
	if marker_area:
		marker_area.body_entered.connect(_on_marker_area_body_entered)
	
	# Start animation
	if animation_player and animation_player.has_animation("pulse"):
		animation_player.play("pulse")

func _process(delta: float) -> void:
	if not is_active or was_reached:
		return
	
	# Auto-rotate if enabled
	if auto_rotate:
		rotate_y(delta * rotation_speed)

func _configure_marker_type() -> void:
	# Configure the marker appearance based on type
	match marker_type:
		0: # Destination
			marker_color = Color(0.2, 0.8, 0.2)
			_setup_destination_marker()
		1: # Checkpoint
			marker_color = Color(0.2, 0.2, 0.8)
			_setup_checkpoint_marker()
		2: # Quest
			marker_color = Color(0.8, 0.8, 0.2)
			_setup_quest_marker()
		3: # Formula
			marker_color = Color(0.8, 0.2, 0.8)
			_setup_formula_marker()
		4: # Laboratory
			marker_color = Color(0.2, 0.8, 0.8)
			_setup_laboratory_marker()

func _setup_destination_marker() -> void:
	# Basic destination marker
	_update_particle_settings(
		64,         # particle count
		2.0,        # emission radius
		1.2,        # particle size multiplier
		1.0,        # particle speed
		Color(0.2, 0.8, 0.2, 0.7) # particle color
	)
	
	# Set light settings
	light.light_color = marker_color
	light.light_energy = 1.0
	light.omni_range = 3.0

func _setup_checkpoint_marker() -> void:
	# Checkpoint has a more focused beam
	_update_particle_settings(
		32,         # fewer particles
		1.5,        # smaller emission radius
		0.8,        # smaller particles
		1.2,        # faster
		Color(0.2, 0.2, 0.8, 0.7) # blue particles
	)
	
	# Focused light
	light.light_color = marker_color
	light.light_energy = 0.8
	light.omni_range = 2.0

func _setup_quest_marker() -> void:
	# Quest has sparkly particles
	_update_particle_settings(
		48,         # medium particle count
		2.0,        # normal emission radius
		1.0,        # normal particle size
		0.8,        # slower particles
		Color(0.8, 0.8, 0.2, 0.7) # yellow particles
	)
	
	# Warm light
	light.light_color = marker_color
	light.light_energy = 1.2
	light.omni_range = 2.5

func _setup_formula_marker() -> void:
	# Formula has swirling particles
	_update_particle_settings(
		64,         # more particles
		1.8,        # normal emission radius
		0.9,        # normal particle size
		1.5,        # faster particles
		Color(0.8, 0.2, 0.8, 0.7) # purple particles
	)
	
	# Mystical light
	light.light_color = marker_color
	light.light_energy = 1.5
	light.omni_range = 3.0

func _setup_laboratory_marker() -> void:
	# Laboratory has a technical appearance
	_update_particle_settings(
		40,         # medium particle count
		1.6,        # smaller emission radius
		0.7,        # smaller particles
		1.0,        # normal speed
		Color(0.2, 0.8, 0.8, 0.7) # cyan particles
	)
	
	# Tech-looking light
	light.light_color = marker_color
	light.light_energy = 1.0
	light.omni_range = 2.5

func _update_particle_settings(count: int, radius: float, size_mult: float, speed: float, color: Color) -> void:
	if not particles:
		return
	
	# Update particle system
	particles.amount = count
	
	# Get the particle material
	var material = particles.process_material
	if material is ParticleProcessMaterial:
		material.emission_sphere_radius = radius
		material.scale_min = 0.05 * size_mult
		material.scale_max = 0.15 * size_mult
		material.initial_velocity_min = 0.5 * speed
		material.initial_velocity_max = 1.0 * speed
		material.color = color

func _update_colors() -> void:
	# Update light color
	if light:
		light.light_color = marker_color
	
	# Update particle color
	if particles and particles.process_material is ParticleProcessMaterial:
		var material = particles.process_material as ParticleProcessMaterial
		material.color = marker_color.lightened(0.3)
		material.color.a = 0.7  # Semi-transparent
	
	# Update mesh color if we have a custom material
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mesh_material = mesh_instance.get_surface_override_material(0)
		if mesh_material is StandardMaterial3D:
			mesh_material.albedo_color = marker_color.darkened(0.3)
			mesh_material.emission = marker_color
			mesh_material.emission_energy_multiplier = 0.5

func _on_marker_area_body_entered(body: Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP) and is_active and not was_reached:
		_on_reached()

func _on_reached() -> void:
	if was_reached:
		return
	
	was_reached = true
	
	# Play reached effect
	if animation_player.has_animation("reached"):
		animation_player.play("reached")
	else:
		# Default reached effect
		var tween = create_tween()
		tween.tween_property(light, "light_energy", 3.0, 0.3)
		tween.tween_property(light, "light_energy", 0.0, REACHED_EFFECT_DURATION)
		
		# Make particles more intense then fade
		if particles:
			particles.amount = particles.amount * 2
			particles.emitting = true
			
			tween = create_tween()
			tween.tween_interval(1.0)
			tween.tween_callback(func(): particles.emitting = false)
	
	# Play sound effect if available
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Emit signal
	emit_signal("reached")
	
	# Schedule for removal after effect
	var removal_tween = create_tween()
	removal_tween.tween_interval(REACHED_EFFECT_DURATION)
	removal_tween.tween_callback(func(): visible = false)
	removal_tween.tween_interval(0.5)
	removal_tween.tween_callback(queue_free)

func activate() -> void:
	is_active = true
	visible = true
	
	# Start animation
	if animation_player and animation_player.has_animation("pulse"):
		animation_player.play("pulse")

func deactivate() -> void:
	is_active = false
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
